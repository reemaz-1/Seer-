'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const {registerToken,sendStatusPush,statusEvent,tokenId}=require('../push');
const token='valid-fcm-token-for-device-123';
class Store {
  constructor(){this.profiles={c1:{},c2:{}};this.devices=new Map();this.inbox=new Map();this.jobs=new Map();}
  async customer(uid){return this.profiles[uid];}
  async saveToken(id,data){this.devices.set(id,data);}
  async removeOwnedToken(id,uid){if(this.devices.get(id)?.uid===uid)this.devices.delete(id);}
  async ensureInbox(event){if(!this.inbox.has(event.id))this.inbox.set(event.id,{...event,read:false});}
  async claim(id){const job=this.jobs.get(id);if(job?.state==='sent')return {state:'sent'};
    if(job?.state==='sending')return {state:'busy'};
    const sentIds=job?.sentIds??[];this.jobs.set(id,{state:'sending',sentIds});return {state:'claimed',sentIds};}
  async tokens(uid,cutoff){return [...this.devices].map(([id,data])=>({id,...data})).filter(d=>d.uid===uid&&d.updatedAt>=cutoff);}
  async removeTokens(ids){ids.forEach(id=>this.devices.delete(id));}
  async finish(id,sentIds,complete){this.jobs.set(id,{state:complete?'sent':'pending',sentIds});}
}
function message(){return {orderId:'o1',before:{customerId:'c1',status:'accepted'},
  after:{customerId:'c1',status:'onTheWay',vehicleTitle:'Private car details'}};}
function sender(){return {calls:[],responses:null,async sendEachForMulticast(payload){this.calls.push(payload);
  return {responses:this.responses??payload.tokens.map(()=>({success:true}))};}};}
const register=(store,data={token,platform:'android'},uid='c1',verified=true)=>registerToken({uid,verified,data,store});
test('registration requires authentication, verified email and an active customer profile',async()=>{
  const store=new Store();
  await assert.rejects(register(store,undefined,null),{code:'unauthenticated'});
  await assert.rejects(register(store,undefined,'c1',false),{code:'unauthenticated'});
  await assert.rejects(register(store,undefined,'provider-only'),{code:'permission-denied'});
  store.profiles.c1.isSuspended=true;
  await assert.rejects(register(store),{code:'permission-denied'});
  assert.equal(store.devices.size,0);
});
test('tokens are validated and UID comes from authentication, not the payload',async()=>{
  const store=new Store();
  await assert.rejects(register(store,{token:'short',platform:'android'}),{code:'invalid-argument'});
  await assert.rejects(register(store,{token,platform:'web'}),{code:'invalid-argument'});
  await register(store,{token,platform:'android',uid:'c2'});
  assert.equal(store.devices.get(tokenId(token)).uid,'c1');
});
test('one installation moves to the new account and rotation cannot delete another user token',async()=>{
  const store=new Store();await register(store);await register(store,undefined,'c2');
  assert.equal(store.devices.size,1);assert.equal(store.devices.get(tokenId(token)).uid,'c2');
  await register(store,{token:token+'new',previousToken:token,platform:'android'},'c1');
  assert.equal(store.devices.get(tokenId(token)).uid,'c2');
});
test('token rotation removes the prior token owned by this customer',async()=>{
  const store=new Store();await register(store);
  await register(store,{token:token+'new',previousToken:token,platform:'android'});
  assert.equal(store.devices.has(tokenId(token)),false);
});
test('push is produced by the server from an order transition, independently of an open app',async()=>{
  const store=new Store(), messaging=sender();await register(store);
  await sendStatusPush({...message(),store,messaging});
  assert.equal(messaging.calls.length,1);
  const payload=messaging.calls[0];
  assert.deepEqual(payload.tokens,[token]);assert.equal(payload.android.priority,'high');
  assert.equal(payload.android.notification.channelId,'customer_order_updates');
  assert.equal(payload.data.orderId,'o1');assert.equal(payload.data.recipientId,'c1');
  assert.ok(payload.notification.title);assert.ok(!payload.notification.body.includes('Private car'));
});
test('unchanged, unsupported, or reassigned-customer events are ignored',async()=>{
  assert.equal(statusEvent('o1',{customerId:'c1',status:'accepted'},{customerId:'c1',status:'accepted'}),null);
  assert.equal(statusEvent('o1',{customerId:'c1',status:'accepted'},{customerId:'c2',status:'completed'}),null);
  assert.equal(statusEvent('o1',{customerId:'c1',status:'accepted'},{customerId:'c1',status:'unknown'}),null);
  assert.equal(statusEvent('o1',{customerId:'c1',status:'accepted'},{customerId:'c1',status:'constructor'}),null);
});
test('duplicate trigger delivery neither resends push nor resets an already-read inbox event',async()=>{
  const store=new Store(), messaging=sender();await register(store);
  const args={...message(),store,messaging};await sendStatusPush(args);
  store.inbox.get('o1_onTheWay').read=true;await sendStatusPush(args);
  assert.equal(messaging.calls.length,1);assert.equal(store.inbox.get('o1_onTheWay').read,true);
});
test('another account and stale installations never receive the push',async()=>{
  const store=new Store(), messaging=sender();await register(store,undefined,'c2');
  store.devices.set('stale',{uid:'c1',token:'old',updatedAt:new Date(0)});
  await sendStatusPush({...message(),store,messaging});assert.equal(messaging.calls.length,0);
});
test('invalid FCM tokens are removed; permanent delivery markers prevent repeated sends',async()=>{
  const store=new Store(), messaging=sender();await register(store);
  messaging.responses=[{success:false,error:{code:'messaging/registration-token-not-registered'}}];
  await sendStatusPush({...message(),store,messaging});assert.equal(store.devices.size,0);
  assert.equal(store.jobs.get('o1_onTheWay').state,'sent');
});
test('transient failure retries only the devices that did not receive the message',async()=>{
  const store=new Store(), messaging=sender();await register(store);
  await register(store,{token:token+'second',platform:'android'});
  messaging.responses=[{success:true},{success:false,error:{code:'messaging/server-unavailable'}}];
  const args={...message(),store,messaging};await assert.rejects(sendStatusPush(args));
  messaging.responses=null;await sendStatusPush(args);
  assert.deepEqual(messaging.calls[1].tokens,[token+'second']);
});
test('an active delivery lease asks the platform to retry rather than losing the event',async()=>{
  const store=new Store(), messaging=sender();store.jobs.set('o1_onTheWay',{state:'sending'});
  await assert.rejects(sendStatusPush({...message(),store,messaging}),/lease/);
  assert.equal(messaging.calls.length,0);
});
