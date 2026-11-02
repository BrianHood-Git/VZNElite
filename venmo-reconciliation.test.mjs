import test from 'node:test';
import assert from 'node:assert/strict';
import {receiptEntries} from './public/venmo.js';
import {mountVenmoFinances} from './public/venmo-finances.js';
test('ledger distinguishes voluntary, reconciled and unassigned receipts without duplicating cash',()=>{
 const rows=[{transaction_id:'fixture-a',gross_cents:5000,fee_cents:105,contribution_kind:'dues'},
 {transaction_id:'fixture-b',gross_cents:4700,fee_cents:1,contribution_kind:'voluntary'},
 {transaction_id:'fixture-c',gross_cents:5000,fee_cents:105}];
 const entries=receiptEntries(rows);
 assert.deepEqual(entries.filter(r=>r.amount>0).map(r=>r.category),['Dues','Voluntary contributions','Unassigned Venmo']);
 assert.equal(entries.reduce((s,r)=>s+r.amount,0),14489);
});
test('admin reconciliation renders covered players for voluntary gifts and excludes covered dues',async()=>{
 const previous=globalThis.document;let root;
 globalThis.document={createElement(){return root={innerHTML:'',dataset:{},isConnected:true,addEventListener(){}};}};
 try {
  const records={venmo_receipts:[{transaction_id:'fixture',sender:'<sender>',payment_date:'2026-11-01',gross_cents:5000,fee_cents:105}],venmo_reports:[],manual_dues:[{id:'covered',player_id:'aj',period:'2026-11-01',amount_cents:0,paid:false}],venmo_reconciliation_history:[],team_documents:[]};
  const client={from(table){const q={select(){return q},order(){return q},range(){return Promise.resolve({data:records[table]})}};return q;}};
  await mountVenmoFinances({append(){}},{client,roster:[{id:'aj',display_name:'AJ Post'}]});
  assert.match(root.innerHTML,/Save receipt assignment/);
  assert.match(root.innerHTML,/AJ Post/);
  assert.match(root.innerHTML,/preserves sponsorship/);
  assert.doesNotMatch(root.innerHTML,/value="covered"|value="50"|<sender>/);
  assert.match(root.innerHTML,/&lt;sender&gt;/);
 } finally {globalThis.document=previous;}
});
