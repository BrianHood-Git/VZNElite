import test from 'node:test';
import assert from 'node:assert/strict';
import {seedFinances,totals,parseImport} from './public/finances.js';
const fixture=()=>({transactions:[{date:'2026-10-01',description:'Dues',amount:150000,category:'Dues',reference:'TEST-1'},{date:'2026-10-05',description:'Sample gym rental',amount:-20000,category:'Gym rental',reference:'TEST-2'},{date:'2026-10-10',description:'Tournament',amount:-35000,category:'Tournaments',reference:'TEST-3'}],budgets:{Tournaments:{reserved:40000},'Gym rental':{reserved:20000}}});
const header='date,description,amount,category,reference\n';
test('available cash excludes reserved funds and expected payments',()=>assert.deepEqual(totals(fixture()),{cash:95000,reserved:60000,available:35000}));
test('import preserves quoted commas and cents and flags repeated rows',()=>{const rows=parseImport(header+'2026-10-15,"Balls, pumps",-45.25,Equipment,TEST\n2026-10-15,"Balls, pumps",-45.25,Equipment,TEST',[]);assert.equal(rows[0].description,'Balls, pumps');assert.equal(rows[0].amount,-4525);assert.equal(rows[0].duplicate,false);assert.equal(rows[1].duplicate,true);});
test('import detects existing transaction without relying on its reference',()=>assert.equal(parseImport(header+'2026-10-05,Sample gym rental,-200.00,Gym rental,OTHER',fixture().transactions)[0].duplicate,true));
test('invalid dates, amounts, categories and unclosed quotes are rejected',()=>{for(const row of ['2026-02-30,Test,1,Other,x','2026-10-01,Test,1.123,Other,x','2026-10-01,Test,1,Unknown,x','2026-10-01,"Test,1,Other,x'])assert.throws(()=>parseImport(header+row,[]));});

test('production ledger starts empty',()=>assert.deepEqual(totals(seedFinances()),{cash:0,reserved:0,available:0}));
