import test from 'node:test';
import assert from 'node:assert/strict';
import {defaults,playerPlan} from './public/dues.js';
test('standard, partial, full, and capped support calculate in cents',()=>{const s={...defaults(),monthly:15000,months:4};assert.equal(playerPlan(s,'1').total,60000);s.support['1']={amount:5000};assert.equal(playerPlan(s,'1').total,40000);s.support['1']={full:true};assert.equal(playerPlan(s,'1').monthly,0);s.support['1']={amount:20000};assert.equal(playerPlan(s,'1').monthly,0);});
test('full support follows new dues and other players retain standard price',()=>{const s={...defaults(),monthly:15000,months:4};s.support['1']={full:true};s.monthly=17525;s.months=6;assert.equal(playerPlan(s,'1').covered,17525);assert.equal(playerPlan(s,'2').total,105150);delete s.support['1'];assert.equal(playerPlan(s,'1').monthly,17525);});
