import test from 'node:test';
import assert from 'node:assert/strict';
import {contributionEntries,contributionCSV,ledgerCSV,cents,csvCell} from './public/contribution-model.js';
import {parseCSV} from './public/finances.js';
test('receipt ledger excludes voided money and keeps optional gifts distinct from dues',()=>{
 const rows=[{id:'a',player_id:'p',kind:'dues',period:'2026-11-01',net_cents:4895},{id:'b',player_id:'p',kind:'voluntary',period:'2026-11-01',net_cents:4699},{id:'c',player_id:'p',kind:'dues',period:'2026-11-01',net_cents:5000,voided_at:'2026-11-01'}];
 const entries=contributionEntries(rows,[{id:'p',name:'Player'}]);
 assert.equal(entries.reduce((s,r)=>s+r.amount,0),9594);assert.equal(entries[1].category,'Voluntary contributions');assert.match(entries[0].description,/Player/);
});
test('CSV preserves player, payer, dates and net cash without inventing gross or duplicate income',()=>{
 const output=contributionCSV({players:[{id:'p',name:'Player, One'}],dues:[{id:'d',player_id:'p',period:'2026-11-01',amount_cents:0,paid:false}],receipts:[{id:'r',player_id:'p',period:'2026-11-01',kind:'voluntary',credit_cents:0,net_cents:4699,payment_date:'2026-11-01',method:'venmo',payer_name:'=HYPERLINK("bad")',reference:'',note:'Optional'}]});
 const rows=parseCSV(output);assert.equal(rows[1][1],'Player, One');assert.equal(rows[1][3],'Sponsored');assert.equal(rows[2][9],'46.99');assert.equal(rows[2][8][0],"'");assert.equal(rows[1][9],'');assert.doesNotMatch(output,/gross|fee/i);
});
test('amount parser preserves cents and rejects malformed or zero payments; CSV prevents formulas',()=>{
 assert.equal(cents('48.95'),4895);for(const v of ['0','-1','5.555','oops'])assert.throws(()=>cents(v));assert.equal(csvCell(' +SUM(A1)'), '"\' +SUM(A1)"');
});
test('finance export contains player income and expense categories with signed numeric amounts',()=>{
 const output=ledgerCSV([{date:'2026-11-01',description:'Payment',amount:4895,category:'Dues',player_id:'p',period:'2026-11-01',payer:'Parent',method:'venmo'},{date:'2026-11-02',description:'Rental',amount:-14000,category:'Gym rental'}],[{id:'p',name:'Player'}]);
 const rows=parseCSV(output);assert.equal(rows[1][2],'48.95');assert.equal(rows[1][5],'Player');assert.equal(rows[1][7],'Parent');assert.equal(rows[2][2],'-140');assert.equal(rows[2][3],'Gym rental');
});
