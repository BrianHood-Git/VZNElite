import test from 'node:test';
import assert from 'node:assert/strict';
import {mountManualDues} from './public/manual-dues.js';
for(const scenario of [
 {name:'unlinked parent',links:[],allowed:false},
 {name:'parent with their own linked player',links:[{user_id:'parent',player_id:'child',relationship:'parent'}],allowed:true},
 {name:'another parent linked to the player',links:[{user_id:'other',player_id:'child',relationship:'parent'}],allowed:false},
 {name:'player relationship without a guardian link',links:[{user_id:'parent',player_id:'child',relationship:'player'}],allowed:false},
 {name:'failed guardian lookup',links:[],error:true,allowed:false}
])test(scenario.name+' has correct Venmo eligibility',async()=>{
 const previous=globalThis.document;let root;
 globalThis.document={createElement(){return root={innerHTML:'',dataset:{},isConnected:true,addEventListener(){},querySelector(){return {textContent:''}}};},addEventListener(){}};
 try{
  const records={family_links:scenario.links,manual_dues:[{id:'dues',payer_id:'parent',player_id:'child',period:'2026-10-01',amount_cents:5000,paid:false}],venmo_reports:[]};
  const client={from(table){let rows=records[table]||[];const result=()=>scenario.error&&table==='family_links'?{error:{message:'Unavailable'}}:{data:rows};const q={select(){return q},eq(k,v){rows=rows.filter(r=>r[k]===v);return q},order(){return q},range(){return Promise.resolve(result())},then(resolve,reject){return Promise.resolve(result()).then(resolve,reject)}};return q}};
  await mountManualDues({append(){}},{client,user:{id:'parent'},roles:['parent'],roster:[{id:'child',display_name:'Child'}]});
  assert.equal(root.innerHTML.includes('href="https://venmo.com/VZNElite2030"'),scenario.allowed);
  assert.equal(root.innerHTML.includes('data-venmo-report='),scenario.allowed);
  if(!scenario.allowed&&!scenario.error)assert.match(root.innerHTML,/disabled>Pay with Venmo — player link required/);
 }finally{globalThis.document=previous;}
});
