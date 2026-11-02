import test from 'node:test';
import assert from 'node:assert/strict';
import {deliverTeamEmails} from './worker/team-emails.js';
const env={TEAM_EMAILS_ENABLED:'true',RESEND_API_KEY:'test',MAIL_FROM:'VZN Elite <notifications@vznelite.org>',SITE_ORIGIN:'https://vznelite.org'};
test('team delivery remains disabled without its feature flag',async()=>{await deliverTeamEmails({},()=>{throw Error('Should not query');});});
test('team email is private, uses stable retry keys, and links practice to schedule',async t=>{
 const original=globalThis.fetch;t.after(()=>globalThis.fetch=original);const messages=[],writes=[];
 globalThis.fetch=async(url,o)=>{assert.equal(url,'https://api.resend.com/emails');messages.push({headers:o.headers,body:JSON.parse(o.body)});return Response.json({id:'provider-message'});};
 const db=async(e,path,options)=>{if(path.startsWith('rpc/'))return [{id:'job-1',email:'parent@example.invalid',subject:'Practice reminder',message:'Thursday 6:30 PM Central',kind:'practice'}];writes.push(options.body);return [];};
 await deliverTeamEmails(env,db);await deliverTeamEmails(env,db);
 assert.deepEqual(messages[0].body.to,['parent@example.invalid']);assert.equal(messages[0].body.from,env.MAIL_FROM);
 assert.equal(messages[0].headers['Idempotency-Key'],messages[1].headers['Idempotency-Key']);assert.match(messages[0].body.text,/#schedule/);assert.ok(writes.every(w=>w.sent_at));
});
test('provider failure leaves the email retryable without marking it sent',async t=>{
 const original=globalThis.fetch;t.after(()=>globalThis.fetch=original);globalThis.fetch=async()=>new Response('',{status:429});let failure;
 await deliverTeamEmails(env,async(e,path,o)=>{if(path.startsWith('rpc/'))return [{id:'retry',email:'parent@example.invalid',subject:'Announcement',message:'Team update',kind:'announcement'}];failure=o.body;return [];});
 assert.equal(failure.sent_at,undefined);assert.match(failure.last_error,/retry/);
});
