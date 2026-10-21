import test from 'node:test';
import assert from 'node:assert/strict';
import {mountManualDues} from './public/manual-dues.js';
test('admin personal contribution view shows only their child and supports reporting without admin payment controls',async()=>{
 const previous=globalThis.document;let root;
 globalThis.document={createElement(){return root={innerHTML:'',dataset:{},isConnected:true,addEventListener(){},querySelector(){return {textContent:''}}};},addEventListener(){}};
 try{
  const records={manual_dues:[{id:'own',payer_id:'admin-parent',player_id:'child',period:'2026-10-01',amount_cents:5000,paid:false},{id:'other',payer_id:'someone-else',player_id:'other-child',period:'2026-10-01',amount_cents:12500,paid:false}],venmo_reports:[]};
  const client={from(table){let rows=records[table]||[];const q={select(){return q},eq(k,v){rows=rows.filter(r=>r[k]===v);return q},order(){return q},range(){return Promise.resolve({data:rows})},then(resolve,reject){return Promise.resolve({data:rows}).then(resolve,reject)}};return q}};
  await mountManualDues({append(){}},{client,user:{id:'admin-parent'},roles:['administrator'],roster:[{id:'child',display_name:'Own child'}],personal:true});
  assert.match(root.innerHTML,/Pay with Venmo/);assert.match(root.innerHTML,/Own child/);assert.match(root.innerHTML,/I sent payment/);assert.doesNotMatch(root.innerHTML,/125\.00|data-manual="payment"|data-manual="create"|other-child/);assert.equal(root.dataset.workspace,undefined);
 }finally{globalThis.document=previous;}
});
