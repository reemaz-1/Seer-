'use strict';
const {createHash} = require('node:crypto');
const STATUS_TITLES = Object.freeze({
  accepted: 'تم قبول طلبك',
  onTheWay: 'مقدم الخدمة في الطريق إليك',
  arrived: 'وصل مقدم الخدمة إلى موقعك',
  inProgress: 'بدأ تنفيذ الخدمة',
  completed: 'اكتملت الخدمة، يمكنك الآن تقييم مقدم الخدمة',
  rejected: 'لم يقبل أي مقدم خدمة طلبك',
  autoCancelled: 'انتهت مهلة الطلب دون استجابة',
  cancelled: 'تم إلغاء طلبك',
});
class RegistrationError extends Error {
  constructor(code, message) { super(message); this.code = code; }
}
const tokenId = token => createHash('sha256').update(token).digest('hex');
function validToken(token) {
  return typeof token === 'string' && token.length >= 16 && token.length <= 4096 && !/\s/.test(token);
}
async function registerToken({uid, verified, data, store, now = new Date()}) {
  if (!uid || !verified) throw new RegistrationError('unauthenticated', 'A verified customer session is required.');
  if (!validToken(data?.token) || data.platform !== 'android' ||
      (data.previousToken != null && !validToken(data.previousToken))) {
    throw new RegistrationError('invalid-argument', 'Invalid device registration.');
  }
  const customer = await store.customer(uid);
  if (!customer || customer.isSuspended === true) {
    throw new RegistrationError('permission-denied', 'An active customer account is required.');
  }
  // Global token ownership changes on account switch: the same installation
  // cannot remain attached to the previous customer's account.
  await store.saveToken(tokenId(data.token), {uid, token: data.token, platform:'android', updatedAt:now});
  if (data.previousToken && data.previousToken !== data.token) {
    await store.removeOwnedToken(tokenId(data.previousToken), uid);
  }
  return {uid};
}
function statusEvent(orderId, before, after) {
  if (!before || !after || before.status === after.status ||
      typeof after.customerId !== 'string' || !after.customerId ||
      before.customerId !== after.customerId || typeof after.status !== 'string' ||
      !Object.hasOwn(STATUS_TITLES, after.status)) return null;
  return {id:`${orderId}_${after.status}`, orderId, recipientId:after.customerId,
    status:after.status, title:STATUS_TITLES[after.status],
    body:[after.serviceOptionLabel, after.vehicleTitle].filter(v=>typeof v==='string' && v.trim()).join(' · ')};
}
function payload(event, tokens) {
  return {tokens,
    // Keep lock-screen content generic; order details require the signed-in app.
    notification:{title:event.title, body:'افتح سير لمتابعة تفاصيل طلبك.'},
    data:{type:'orderStatusChanged', orderId:event.orderId, recipientId:event.recipientId, status:event.status},
    android:{priority:'high', notification:{channelId:'customer_order_updates',
      tag:event.id, sound:'default', icon:'ic_stat_order_update'}},
  };
}
async function sendStatusPush({orderId, before, after, store, messaging, now = new Date()}) {
  const event = statusEvent(orderId, before, after);
  if (!event) return {ignored:true};
  await store.ensureInbox(event);
  const claim = await store.claim(event.id, now);
  if (claim.state === 'sent') return {duplicate:true};
  if (claim.state === 'busy') throw new Error('Push delivery lease is still active.');
  const sent = new Set(claim.sentIds);
  let retry = false;
  try {
    const cutoff = new Date(now.getTime()-30*24*60*60*1000);
    const devices = (await store.tokens(event.recipientId, cutoff)).filter(d=>!sent.has(d.id));
    for (let i=0;i<devices.length;i+=500) {
      const chunk=devices.slice(i,i+500);
      const result=await messaging.sendEachForMulticast(payload(event,chunk.map(d=>d.token)));
      const invalid=[];
      result.responses.forEach((response,index)=>{
        const device=chunk[index];
        if(response.success) sent.add(device.id);
        else if(['messaging/registration-token-not-registered','messaging/invalid-registration-token'].includes(response.error?.code)) {
          invalid.push(device.id); sent.add(device.id);
        } else retry=true;
      });
      if(invalid.length) await store.removeTokens(invalid);
    }
  } catch(error) {
    await store.finish(event.id,[...sent],false);
    throw error;
  }
  await store.finish(event.id,[...sent],!retry);
  if(retry) throw new Error('Some push deliveries need retry.');
  return {sent:sent.size};
}
module.exports={registerToken, sendStatusPush, statusEvent, payload, tokenId, RegistrationError};
