import test from 'node:test';import assert from 'node:assert/strict';
import {vendorValues,filterVendors,safeVendorURL} from './public/tournament-vendors.js';
import {planningValues} from './public/tournament-planning-model.js';
test('vendor URLs reject executable schemes and embedded credentials',()=>{
 assert.equal(safeVendorURL('https://example.com'),'https://example.com/');assert.equal(safeVendorURL(''),'');
 for(const v of ['javascript:alert(1)','data:text/html,test','https://user:password@example.com','example.com'])assert.throws(()=>safeVendorURL(v));
});
test('vendor search finds private contacts and excludes archived entries by default',()=>{
 const rows=[{organization:'Gym',contact_name:'Gino',archived:false},{organization:'Old gym',contact_name:'Gino',archived:true}];
 assert.equal(filterVendors(rows,'gino').length,1);assert.equal(filterVendors(rows,'gino',true).length,2);
 assert.throws(()=>vendorValues(new Map([['organization','Gym'],['email','invalid']])));
});
test('tournament planning permits unknown times in drafts and limits multi-day ranges',()=>{
 const d=new Map([['event_date','2026-11-14'],['end_date','2026-11-15'],['planning_status','registered']]);
 assert.equal(planningValues(d).start_time,null);d.set('start_time','09:00');assert.equal(planningValues(d).start_time,'09:00');
 d.set('end_date','2026-11-22');assert.throws(()=>planningValues(d));d.set('end_date','2026-11-13');assert.throws(()=>planningValues(d));
 d.set('end_date','2026-11-15');d.set('start_time','25:00');assert.throws(()=>planningValues(d));d.set('start_time','09:00');d.set('registration_url','javascript:alert(1)');assert.throws(()=>planningValues(d));
});
