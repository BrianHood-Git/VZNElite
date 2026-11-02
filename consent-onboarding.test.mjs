import test from 'node:test';
import assert from 'node:assert/strict';
import {needsConsent} from './public/consent-onboarding.js';
import {policyVersion} from './public/policies.js';
const record={player_id:'child',parent_id:'parent',recorded_at:'2026-10-18T12:00:00Z',version:policyVersion,payload:{guardian:true,participation:true,conduct:true,electronic:true,media:false,profile:false}};
test('optional publication choices do not block completed consent',()=>assert.equal(needsConsent([record],'child','parent'),false));
test('consent is specific to each child and guardian',()=>{assert.equal(needsConsent([record],'sibling','parent'),true);assert.equal(needsConsent([record],'child','other-parent'),true);});
test('latest withdrawal or new policy requires fresh consent',()=>{assert.equal(needsConsent([record,{...record,recorded_at:'2026-10-18T13:00:00Z',payload:{withdrawn:true}}],'child','parent'),true);assert.equal(needsConsent([{...record,version:'old'}],'child','parent'),true);});
