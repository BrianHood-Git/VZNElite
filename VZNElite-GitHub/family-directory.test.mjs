import test from 'node:test';
import assert from 'node:assert/strict';
import {parentSummary} from './public/family-directory.js';
const players=[{id:'p1',roster_status:'active',billing_parent_id:'a'},{id:'p2',roster_status:'active',billing_parent_id:'a'},{id:'p3',roster_status:'former',billing_parent_id:'a'}];
const links=[{user_id:'a',player_id:'p1',relationship:'parent'},{user_id:'b',player_id:'p1',relationship:'parent'},{user_id:'a',player_id:'p2',relationship:'parent'},{user_id:'a',player_id:'p3',relationship:'parent'}];
const dues={monthly:15000,months:4,support:{p2:{amount:5000}}};
test('parent totals include active responsible siblings after sponsorship',()=>{const summary=parentSummary('a',players,links,dues);assert.equal(summary.assigned.length,3);assert.equal(summary.monthly,25000);assert.equal(summary.total,100000);});
test('shared guardian sees assignment without duplicate billing ownership',()=>{const summary=parentSummary('b',players,links,dues);assert.equal(summary.assigned.length,1);assert.equal(summary.monthly,0);assert.equal(summary.total,0);});
test('unlinked account has no assigned players or dues total',()=>assert.deepEqual(parentSummary('other',players,links,dues),{assigned:[],monthly:0,total:0}));
