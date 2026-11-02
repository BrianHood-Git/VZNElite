import test from 'node:test';
import assert from 'node:assert/strict';
import {reconciliationOverview} from './public/payment-reconciliation.js';
test('reconciliation keeps sponsorship, paid status and unmatched gross payments distinct',()=>{
 const html=reconciliationOverview({month:'2026-11',roster:[{id:'aj',display_name:'AJ'},{id:'steele',display_name:'Steele'},{id:'johann',display_name:'Johann'},{id:'old',display_name:'Former',roster_status:'former'}],dues:[{player_id:'steele',period:'2026-11-01',amount_cents:5000,paid:true}],reports:[],receipts:[{}],settings:{monthly:5000,support:{aj:{full:true}}},pending:[{month:'2026-11',sender:'Crystal <unknown>',gross_cents:5000,note:'Allocation unknown'}]});
 assert.match(html,/Fully sponsored/);assert.match(html,/Steele<\/td><td>\$50.00<\/td><td>Paid/);assert.match(html,/Johann<\/td><td>\$50.00<\/td><td>No confirmed payment/);assert.match(html,/Crystal &lt;unknown&gt;/);assert.match(html,/Unmatched player/);assert.doesNotMatch(html,/Former/);
});
