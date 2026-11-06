const {readFileSync} = require('node:fs');
const {test, before, after, beforeEach} = require('node:test');
const assert = require('node:assert/strict');
const {initializeTestEnvironment, assertSucceeds, assertFails} = require('@firebase/rules-unit-testing');
const {doc, getDoc, setDoc, updateDoc, writeBatch, runTransaction, serverTimestamp, Timestamp, deleteField} = require('firebase/firestore');
let env;
const projectId = 'demo-seer-shams';
before(async () => { env = await initializeTestEnvironment({projectId, firestore: {
  host:'127.0.0.1', port:8185, rules:readFileSync(__dirname+'/../firestore.rules','utf8')
}}); });
after(async () => { await env?.cleanup(); });
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async ctx => {
    const db=ctx.firestore();
    await setDoc(doc(db,'customers/c1'), {firstName:'Customer'});
    await setDoc(doc(db,'customers/c2'), {firstName:'Other'});
    await setDoc(doc(db,'providers/p1'), {status:'approved', ratingCount:2, ratingSum:8, rating:4});
    for (const id of ['o1','o2']) await setDoc(doc(db,'orders/'+id), {
      customerId:'c1', providerId:'p1', status:'completed', candidateProviderIds:['p1'], rejectedBy:[],
      expiresAt:Timestamp.fromMillis(Date.now()+60000),
    });
  });
});
const customer = (uid='c1') => env.authenticatedContext(uid).firestore();
const provider = () => env.authenticatedContext('p1',{email_verified:true}).firestore();
async function rate(db,id,stars) {
  for(let attempt=0;attempt<3;attempt++) {
  try { return await runTransaction(db,async tx => {
    const r=doc(db,'ratings/'+id), p=doc(db,'providers/p1');
    const existing=await tx.get(r), ps=await tx.get(p);
    if(existing.exists()) throw new Error('Already rated');
    const count=ps.data().ratingCount+1, sum=ps.data().ratingSum+stars;
    tx.set(r,{orderId:id,customerId:'c1',providerId:'p1',stars,createdAt:serverTimestamp()});
    tx.update(p,{ratingCount:count,ratingSum:sum,rating:sum/count,lastRatingOrderId:id});
  }); } catch(error) {
    if(error.code==='permission-denied' && attempt<2) continue;
    throw error;
  }
  }
}
test('rating aggregate and record commit atomically; duplicate is denied', async()=>{
  const db=customer(); await assertSucceeds(rate(db,'o1',5));
  const p=(await getDoc(doc(db,'providers/p1'))).data();
  assert.equal(p.ratingCount,3); assert.equal(p.rating,13/3);
  await assert.rejects(rate(db,'o1',1),/Already rated/);
  await assertFails(updateDoc(doc(db,'ratings/o1'),{stars:1}));
});
test('two concurrent completed orders contribute exactly once each', async()=>{
  const db=customer(); await Promise.all([rate(db,'o1',5),rate(customer(),'o2',3)]);
  const p=(await getDoc(doc(db,'providers/p1'))).data();
  assert.equal(p.ratingCount,4); assert.equal(p.ratingSum,16); assert.equal(p.rating,4);
});
for(const stars of [0,6,1.5]) test('reject invalid stars '+stars, async()=>{
  await assertFails(rate(customer(),'o1',stars));
});
test('cannot forge the average or create a rating without its aggregate', async()=>{
  const db=customer();
  await assertFails(updateDoc(doc(db,'providers/p1'),{rating:5}));
  await assertFails(setDoc(doc(db,'ratings/o1'),{orderId:'o1',customerId:'c1',providerId:'p1',stars:5,createdAt:serverTimestamp()}));
});
test('a foreign customer cannot rate the order or read its rating', async()=>{
  await assertFails(rate(customer('c2'),'o1',5));
  await assertFails(getDoc(doc(customer('c2'),'ratings/o1')));
});
test('an unfinished order cannot be rated', async()=>{
  await env.withSecurityRulesDisabled(ctx=>updateDoc(doc(ctx.firestore(),'orders/o1'),{status:'inProgress'}));
  await assertFails(rate(customer(),'o1',5));
});
async function transition(from,to,actor=provider()) {
  await env.withSecurityRulesDisabled(ctx=>updateDoc(doc(ctx.firestore(),'orders/o1'),{status:from}));
  const batch=writeBatch(actor);
  batch.update(doc(actor,'orders/o1'),{status:to,[to+'At']:serverTimestamp()});
  batch.set(doc(actor,'notifications/o1_'+to),{recipientId:'c1',type:'orderStatusChanged',orderId:'o1',status:to,
    title:'Status updated',body:'Service',read:false,createdAt:serverTimestamp()});
  return batch.commit();
}
for (const [from,to] of [['accepted','onTheWay'],['onTheWay','arrived'],['arrived','inProgress']]) {
  test('status '+to+' notifies its customer in the same commit',async()=>{
    await assertSucceeds(transition(from,to));
    await assertSucceeds(getDoc(doc(customer(),'notifications/o1_'+to)));
    await assertFails(getDoc(doc(customer('c2'),'notifications/o1_'+to)));
  });
}
test('acceptance can claim the provider and notify the customer',async()=>{
  await env.withSecurityRulesDisabled(ctx=>updateDoc(doc(ctx.firestore(),'orders/o1'),{status:'pending',providerId:null}));
  const db=provider(), batch=writeBatch(db);
  batch.update(doc(db,'orders/o1'),{status:'accepted',providerId:'p1',acceptedAt:serverTimestamp()});
  batch.update(doc(db,'providers/p1'),{activeOrderId:'o1'});
  batch.set(doc(db,'notifications/o1_accepted'),{recipientId:'c1',type:'orderStatusChanged',orderId:'o1',status:'accepted',title:'Accepted',body:'Service',read:false,createdAt:serverTimestamp()});
  await assertSucceeds(batch.commit());
});
test('a notice cannot be forged without a real transition',async()=>{
  const db=provider();
  await assertFails(setDoc(doc(db,'notifications/o1_completed'),{recipientId:'c1',type:'orderStatusChanged',orderId:'o1',status:'completed',title:'Forged',body:'',read:false,createdAt:serverTimestamp()}));
});
test('recipients can mark read, but cannot rewrite or redirect the notice',async()=>{
  await transition('accepted','onTheWay');
  const db=customer(), ref=doc(db,'notifications/o1_onTheWay');
  await assertSucceeds(updateDoc(ref,{read:true}));
  await assertFails(updateDoc(ref,{recipientId:'c2'}));
  await assertFails(updateDoc(ref,{title:'Changed'}));
});

test('completion confirms payment, releases the provider and notifies the customer',async()=>{
  await env.withSecurityRulesDisabled(async ctx=>{
    await updateDoc(doc(ctx.firestore(),'orders/o1'),{status:'inProgress'});
    await updateDoc(doc(ctx.firestore(),'providers/p1'),{activeOrderId:'o1'});
  });
  const db=provider(), batch=writeBatch(db);
  batch.update(doc(db,'orders/o1'),{status:'completed',paymentConfirmed:true,finalPrice:150,completedAt:serverTimestamp(),completedDay:'2026-11-06'});
  batch.update(doc(db,'providers/p1'),{activeOrderId:deleteField()});
  batch.set(doc(db,'notifications/o1_completed'),{recipientId:'c1',type:'orderStatusChanged',orderId:'o1',status:'completed',title:'Completed',body:'Service',read:false,createdAt:serverTimestamp()});
  await assertSucceeds(batch.commit());
});
test('final rejection notifies the customer',async()=>{
  await env.withSecurityRulesDisabled(ctx=>updateDoc(doc(ctx.firestore(),'orders/o1'),{status:'pending',providerId:null}));
  const db=provider(), batch=writeBatch(db);
  batch.update(doc(db,'orders/o1'),{status:'rejected',rejectedBy:['p1']});
  batch.set(doc(db,'notifications/o1_rejected'),{recipientId:'c1',type:'orderStatusChanged',orderId:'o1',status:'rejected',title:'Rejected',body:'Service',read:false,createdAt:serverTimestamp()});
  await assertSucceeds(batch.commit());
});
test('expired requests save their expiry notice with auto-cancellation',async()=>{
  await env.withSecurityRulesDisabled(ctx=>updateDoc(doc(ctx.firestore(),'orders/o1'),{status:'pending',providerId:null,expiresAt:Timestamp.fromMillis(Date.now()-1000)}));
  const db=customer(), batch=writeBatch(db);
  batch.update(doc(db,'orders/o1'),{status:'autoCancelled',cancelledAt:serverTimestamp()});
  batch.set(doc(db,'notifications/o1_autoCancelled'),{recipientId:'c1',type:'orderStatusChanged',orderId:'o1',status:'autoCancelled',title:'Expired',body:'Service',read:false,createdAt:serverTimestamp()});
  await assertSucceeds(batch.commit());
});

test('a missing stale active-order pointer does not block a legitimate acceptance',async()=>{
  await env.withSecurityRulesDisabled(async ctx=>{
    await updateDoc(doc(ctx.firestore(),'providers/p1'),{activeOrderId:'deleted-order'});
    await updateDoc(doc(ctx.firestore(),'orders/o1'),{status:'pending',providerId:null});
  });
  const db=provider(), batch=writeBatch(db);
  batch.update(doc(db,'orders/o1'),{status:'accepted',providerId:'p1',acceptedAt:serverTimestamp()});
  batch.update(doc(db,'providers/p1'),{activeOrderId:'o1'});
  await assertSucceeds(batch.commit());
});
test('an active provider cannot overwrite their current assignment',async()=>{
  await env.withSecurityRulesDisabled(async ctx=>{
    await updateDoc(doc(ctx.firestore(),'providers/p1'),{activeOrderId:'o2'});
    await updateDoc(doc(ctx.firestore(),'orders/o2'),{status:'onTheWay'});
    await updateDoc(doc(ctx.firestore(),'orders/o1'),{status:'pending',providerId:null});
  });
  const db=provider(), batch=writeBatch(db);
  batch.update(doc(db,'orders/o1'),{status:'accepted',providerId:'p1',acceptedAt:serverTimestamp()});
  batch.update(doc(db,'providers/p1'),{activeOrderId:'o1'});
  await assertFails(batch.commit());
});
