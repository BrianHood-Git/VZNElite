import test from 'node:test';
import assert from 'node:assert/strict';
import {mountDues,defaults,playerPlan} from './public/dues.js';
import {mountManualDues} from './public/manual-dues.js';

test('support selector loads existing full support and saves half support without changing other players',async()=>{
 const previous={document:globalThis.document,FormData:globalThis.FormData};let root,saved=0;const handlers={};
 globalThis.document={createElement(){return root={innerHTML:'',addEventListener(k,f){handlers[k]=f}}},dispatchEvent(){}};
 globalThis.FormData=class{constructor(form){this.values=form.values}get(k){return this.values[k]??null}};
 try{
  const state={dues:defaults(),players:[{id:'aj',name:'AJ Post'},{id:'other',name:'Other player'}]};state.dues.support.aj={full:true,amount:0,note:'Existing sponsor'};
  mountDues({prepend(){}},{state,save:async()=>{saved++;return true},toast(){},isAdmin:()=>true});
  handlers.change({target:{name:'player',value:'aj'}});
  assert.match(root.innerHTML,/value="full" selected/);assert.match(root.innerHTML,/Existing sponsor/);assert.doesNotMatch(root.innerHTML,/<table|Monthly installments/);
  await handlers.submit({preventDefault(){},stopPropagation(){},target:{id:'support-settings',values:{player:'aj',kind:'half',note:'Half support'}}});
  assert.equal(saved,1);assert.equal(playerPlan(state.dues,'aj').monthly,2500);assert.equal(playerPlan(state.dues,'other').monthly,5000);
  await handlers.submit({preventDefault(){},stopPropagation(){},target:{id:'dues-settings',values:{monthly:'60'}}});
  assert.equal(playerPlan(state.dues,'aj').monthly,3000);
 }finally{Object.assign(globalThis,previous)}
});

test('admin starts with a single player selector and displays only the selected player',async()=>{
 const previous=globalThis.document;let root;const handlers={};
 globalThis.document={createElement(){return root={innerHTML:'',dataset:{},isConnected:true,addEventListener(k,f){handlers[k]=f},querySelector(){return {textContent:''}}}},addEventListener(){}};
 try{
  const records={manual_dues:[{id:'a',player_id:'paid',period:'2026-11-01',paid:true,amount_cents:5000},{id:'b',player_id:'due',period:'2026-11-01',paid:false,amount_cents:2500},{id:'c',player_id:'covered',period:'2026-11-01',paid:false,amount_cents:0}],manual_dues_history:[],venmo_reports:[]};
  records.player_contributions=[];records.venmo_receipts=[];records.team_documents={version:1,data:{monthly:5000,months:1,support:{covered:{full:true}}}};const client={from(t){const q={select(){return q},eq(){return q},single(){return Promise.resolve({data:records[t]})},order(){return q},range(){return Promise.resolve({data:records[t]})},then(resolve){return Promise.resolve({data:records[t]}).then(resolve)}};return q}};
  await mountManualDues({append(){}},{client,roles:['administrator'],user:{id:'admin'},roster:['paid','due','covered','missing'].map(id=>({id,display_name:id}))});
  assert.match(root.innerHTML,/Start with a player/);assert.doesNotMatch(root.innerHTML,/<table/);
  await handlers.change({target:{value:'covered',matches(selector){return selector==='[data-player]'}}});
  assert.match(root.innerHTML,/Fully sponsored/);assert.match(root.innerHTML,/Record an optional parent contribution/);assert.doesNotMatch(root.innerHTML,/data-action="dues"/);
 }finally{globalThis.document=previous}
});
