import test from 'node:test';
import assert from 'node:assert/strict';
import worker from './worker/index.js';
test('production HTTP redirects to HTTPS before serving any content',async()=>{
 const r=await worker.fetch(new Request('http://vznelite.org/?flow=recovery'),{});
 assert.equal(r.status,308);assert.equal(r.headers.get('location'),'https://vznelite.org/?flow=recovery');
});
test('API throttling denies repeated requests before authentication/provider calls',async()=>{
 const r=await worker.fetch(new Request('https://vznelite.org/api/checkout',{method:'POST',headers:{Origin:'https://vznelite.org','CF-Connecting-IP':'192.0.2.1'},body:'{}'}),{API_RATE_LIMIT:{limit:async({key})=>{assert.equal(key,'192.0.2.1');return {success:false};}}});
 assert.equal(r.status,429);assert.equal(r.headers.get('cache-control'),'no-store');assert.equal(r.headers.get('x-frame-options'),'DENY');assert.ok(r.headers.get('strict-transport-security'));
});
test('retired card checkout stays disabled after the rate-limit check',async()=>{
 const r=await worker.fetch(new Request('https://vznelite.org/api/checkout',{method:'POST',headers:{Origin:'https://vznelite.org'},body:'{}'}),{SITE_ORIGIN:'https://vznelite.org',API_RATE_LIMIT:{limit:async()=>({success:true})}});
 assert.equal(r.status,410);
});
