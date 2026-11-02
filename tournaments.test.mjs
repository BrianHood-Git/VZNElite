import test from 'node:test';
import assert from 'node:assert/strict';
import {tournamentAmount,tournamentTotals,tournamentValues} from './public/tournaments.js';
test('tournament amounts preserve cents and unknown cost',()=>{
 assert.equal(tournamentAmount(''),null);assert.equal(tournamentAmount('125.09'),12509);assert.equal(tournamentAmount('0'),0);
 for(const n of ['-1','1.001','Infinity','1e3','1000001'])assert.throws(()=>tournamentAmount(n));
});
test('tournament totals exclude archived records and distinguish unknown costs',()=>{
 assert.deepEqual(tournamentTotals([{cost_cents:10000,paid_cents:2500},{cost_cents:null,paid_cents:1000},{cost_cents:40000,paid_cents:40000,archived:true}]),{cost:10000,paid:3500,remaining:7500,unknown:1});
});
test('tournament forms reject overpayments and invalid dates while allowing unknown costs',()=>{
 const d=new Map([['name','Sample'],['cost','100'],['paid','50'],['event_date','2026-10-18']]);assert.equal(tournamentValues(d).paid_cents,5000);
 d.set('paid','101');assert.throws(()=>tournamentValues(d));d.set('cost','');assert.equal(tournamentValues(d).cost_cents,null);
 d.set('event_date','2026-02-30');assert.throws(()=>tournamentValues(d));
});
