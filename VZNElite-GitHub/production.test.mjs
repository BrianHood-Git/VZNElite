import test from 'node:test';
import assert from 'node:assert/strict';
import {verifyStripeSignature,validateCheckoutInvoice,safeOrigin} from './worker/security.js';
import worker,{deliverNotifications} from './worker/index.js';
async function signature(body,secret,time){const key=await crypto.subtle.importKey('raw',new TextEncoder().encode(secret),{name:'HMAC',hash:'SHA-256'},false,['sign']);const bytes=await crypto.subtle.sign('HMAC',key,new TextEncoder().encode(time+'.'+body));return 't='+time+',v1='+Array.from(new Uint8Array(bytes),x=>x.toString(16).padStart(2,'0')).join('');}
test('Stripe signatures reject body changes, stale timestamps and wrong keys',async()=>{const raw='{"id":"evt_1"}',secret='test-key',time=Math.floor(Date.now()/1000),sig=await signature(raw,secret,time);assert.equal(await verifyStripeSignature(raw,sig,secret),true);assert.equal(await verifyStripeSignature(raw+' ',sig,secret),false);assert.equal(await verifyStripeSignature(raw,sig,'wrong'),false);assert.equal(await verifyStripeSignature(raw,sig,secret,(time+301)*1000),false);assert.equal(await verifyStripeSignature(raw,'t=bad,v1=bad',secret),false);});
test('checkout refuses cross-family, paid, zero and fractional invoices',()=>{const i={payer_id:'parent-a',status:'open',amount_cents:15000};assert.doesNotThrow(()=>validateCheckoutInvoice(i,'parent-a'));assert.throws(()=>validateCheckoutInvoice(i,'parent-b'));for(const change of [{status:'paid'},{amount_cents:0},{amount_cents:12.3}])assert.throws(()=>validateCheckoutInvoice({...i,...change},'parent-a'));});
test('return origin requires an exact HTTPS origin',()=>{assert.equal(safeOrigin('https://vznelite.org'),'https://vznelite.org');for(const value of ['http://vznelite.org','https://vznelite.org/path','https://vznelite.org/?x=1'])assert.throws(()=>safeOrigin(value));});
test('legacy card routes are disabled',async()=>{for(const path of ['checkout','invoices'])assert.equal((await worker.fetch(new Request('https://vznelite.org/api/'+path,{method:'POST',body:'{}'}),{})).status,410);});
test('notifications do nothing until explicitly enabled',async()=>{await deliverNotifications({NOTIFICATIONS_ENABLED:'false'});});
test('unsigned webhooks and unpaid checkout events cannot record payment',async t=>{
 const original=globalThis.fetch;t.after(()=>globalThis.fetch=original);let writes=0;globalThis.fetch=async()=>{writes++;return Response.json(null);};const env={STRIPE_WEBHOOK_SECRET:'whsec_test'};
 let r=await worker.fetch(new Request('https://vznelite.org/api/stripe-webhook',{method:'POST',body:'{}'}),env);assert.equal(r.status,400);
 const body=JSON.stringify({id:'evt_1',type:'checkout.session.completed',data:{object:{payment_status:'unpaid'}}}),time=Math.floor(Date.now()/1000);
 r=await worker.fetch(new Request('https://vznelite.org/api/stripe-webhook',{method:'POST',headers:{'stripe-signature':await signature(body,env.STRIPE_WEBHOOK_SECRET,time)},body}),env);assert.equal(r.status,200);assert.equal(writes,0);
});
test('new account email reaches every current verified administrator privately',async t=>{
 const original=globalThis.fetch;t.after(()=>globalThis.fetch=original);const messages=[];let marked=false;
 globalThis.fetch=async(url,o={})=>{url=String(url);if(url.includes('/rpc/claim_admin_notifications'))return Response.json([{id:'n1',user_id:'new-user'}]);if(url.includes('team_memberships?'))return Response.json([{user_id:'a'},{user_id:'b'},{user_id:'unverified'}]);if(url.includes('/auth/v1/admin/users/')){const id=url.split('/').at(-1);return Response.json({email:id+'@example.invalid',email_confirmed_at:id==='unverified'?null:'now'});}if(url==='https://api.resend.com/emails'){messages.push(JSON.parse(o.body));return Response.json({id:'sent'});}if(o.method==='PATCH'){marked=true;return Response.json([]);}throw Error('Unexpected request '+url);};
 await deliverNotifications({NOTIFICATIONS_ENABLED:'true',RESEND_API_KEY:'test',MAIL_FROM:'team@example.invalid',SITE_ORIGIN:'https://vznelite.org',SUPABASE_URL:'https://db.example',SUPABASE_SERVICE_ROLE_KEY:'server'});
 assert.equal(messages.length,2);assert.deepEqual(messages.map(x=>x.to),[['a@example.invalid'],['b@example.invalid']]);assert.equal(marked,true);
});
