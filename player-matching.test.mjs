import test from 'node:test';
import assert from 'node:assert/strict';
import {matchingPlayers} from './public/family-onboarding.js';
test('matches ignore capitalization and repeated whitespace, not jersey numbers',()=>{
 const roster=[{id:'old',display_name:'Johann Melendez',jersey_number:'2'},{id:'other',display_name:'Johann Smith'}];
 assert.deepEqual(matchingPlayers(roster,'  JOHANN   Melendez '),[roster[0]]);
 assert.deepEqual(matchingPlayers(roster,'John Melendez'),[]);
});
test('ambiguous and former matches remain visible for staff review',()=>{
 const roster=[{id:'a',display_name:'Luke Beyer',roster_status:'former'},{id:'b',display_name:'Luke Beyer',roster_status:'active'}];
 assert.equal(matchingPlayers(roster,'Luke Beyer').length,2);
});
