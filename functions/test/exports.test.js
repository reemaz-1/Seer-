'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const {readFileSync}=require('node:fs');
process.env.GCLOUD_PROJECT='demo-seer-shams';
test('deployment loads both callable and order-trigger handlers without production credentials',()=>{
  const handlers=require('../index');
  assert.equal(typeof handlers.registerCustomerPushToken,'function');
  assert.equal(typeof handlers.sendCustomerOrderStatusPush,'function');
  assert.equal(handlers.sendCustomerOrderStatusPush.__endpoint.eventTrigger.retry,true);
});
test('push deployment config has no Firestore rules or hosting deployment',()=>{
  const config=JSON.parse(readFileSync(__dirname+'/../../firebase.push.json','utf8'));
  assert.deepEqual(Object.keys(config),['functions']);
  assert.equal(config.functions[0].codebase,'customer-push');
});
