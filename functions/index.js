'use strict';
const {initializeApp} = require('firebase-admin/app');
const {getFirestore, FieldValue, Timestamp} = require('firebase-admin/firestore');
const {getMessaging} = require('firebase-admin/messaging');
const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {onDocumentUpdated} = require('firebase-functions/v2/firestore');
const {registerToken, sendStatusPush, RegistrationError} = require('./push');
initializeApp();
const db=getFirestore();
const registrations=db.collection('customerPushTokens');
const deliveries=db.collection('customerPushDeliveries');

// Both collections must be private to Admin SDK before production activation.
// Clients register only through the authenticated callable below.
const store={
  async customer(uid) {return (await db.doc(`customers/${uid}`).get()).data();},
  async saveToken(id,data) {await registrations.doc(id).set(data);},
  async removeOwnedToken(id,uid) {
    await db.runTransaction(async tx=>{
      const ref=registrations.doc(id), snap=await tx.get(ref);
      if(snap.data()?.uid===uid) tx.delete(ref);
    });
  },
  async ensureInbox(event) {
    try {await db.doc(`notifications/${event.id}`).create({
      recipientId:event.recipientId,type:'orderStatusChanged',orderId:event.orderId,
      status:event.status,title:event.title,body:event.body,read:false,
      createdAt:FieldValue.serverTimestamp(),
    });} catch(error) {
      // An upgraded client may already have committed this exact inbox event.
      // Never reset its read flag or timestamp.
      if(error.code!==6 && error.code!=='already-exists') throw error;
    }
  },
  async claim(id,now) {
    return db.runTransaction(async tx=>{
      const ref=deliveries.doc(id), data=(await tx.get(ref)).data();
      if(data?.state==='sent') return {state:'sent'};
      if(data?.leaseUntil?.toMillis()>now.getTime()) return {state:'busy'};
      const sentIds=data?.sentIds ?? [];
      tx.set(ref,{state:'sending',sentIds,leaseUntil:Timestamp.fromMillis(now.getTime()+120000)});
      return {state:'claimed',sentIds};
    });
  },
  async tokens(uid,cutoff) {
    const docs=await registrations.where('uid','==',uid).get();
    return docs.docs.map(doc=>({id:doc.id,...doc.data()}))
      .filter(d=>d.platform==='android' && typeof d.token==='string' &&
        d.updatedAt?.toMillis()>=cutoff.getTime());
  },
  async removeTokens(ids) {
    const batch=db.batch(); ids.forEach(id=>batch.delete(registrations.doc(id)));
    await batch.commit();
  },
  async finish(id,sentIds,complete) {
    await deliveries.doc(id).set({state:complete?'sent':'pending',sentIds,
      leaseUntil:Timestamp.fromMillis(0),updatedAt:FieldValue.serverTimestamp()});
  },
};
exports.registerCustomerPushToken=onCall({region:'us-central1',maxInstances:2},async request=>{
  try {return await registerToken({uid:request.auth?.uid,
    verified:request.auth?.token.email_verified===true,data:request.data,store});}
  catch(error) {
    if(error instanceof RegistrationError) throw new HttpsError(error.code,error.message);
    // Never return token values or private registration documents to the caller.
    throw new HttpsError('internal','Device registration is temporarily unavailable.');
  }
});
exports.sendCustomerOrderStatusPush=onDocumentUpdated({
  document:'orders/{orderId}',region:'us-central1',maxInstances:2,retry:true,
},async event=>{
  if(!event.data) return;
  return sendStatusPush({orderId:event.params.orderId,
    before:event.data.before.data(),after:event.data.after.data(),store,messaging:getMessaging()});
});
