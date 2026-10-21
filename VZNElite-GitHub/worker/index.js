import {deliverTeamEmails} from './team-emails.js';

import {verifyStripeSignature,safeOrigin,limitedBody} from './security.js';

const json=(data,status=200)=>Response.json(data,{status,headers:{'Cache-Control':'no-store','X-Content-Type-Options':'nosniff','Strict-Transport-Security':'max-age=31536000','Referrer-Policy':'no-referrer','X-Frame-Options':'DENY','Content-Security-Policy':"default-src 'none'; frame-ancestors 'none'",'Cross-Origin-Resource-Policy':'same-origin'}});

const fail=(message,status=400)=>Object.assign(Error(message),{status});

async function db(env,path,{token,method='GET',body}={}){

 const key=token?env.SUPABASE_PUBLISHABLE_KEY:env.SUPABASE_SERVICE_ROLE_KEY;if(!key)throw fail('Server setup is incomplete',503);

 const r=await fetch(env.SUPABASE_URL+'/rest/v1/'+path,{method,headers:{apikey:key,Authorization:'Bearer '+(token||key),'Content-Type':'application/json',Prefer:'return=representation'},body:body===undefined?undefined:JSON.stringify(body)});

 if(!r.ok)throw fail('Database operation failed',502);return r.status===204?null:r.json();

}

async function webhook(req,env){

 if(!env.STRIPE_WEBHOOK_SECRET)throw fail('Webhook not configured',503);

 const raw=await limitedBody(req,262144);

 if(!await verifyStripeSignature(raw,req.headers.get('stripe-signature'),env.STRIPE_WEBHOOK_SECRET))throw fail('Invalid signature',400);

 const event=JSON.parse(raw),s=event.data?.object;

 if(['checkout.session.completed','checkout.session.async_payment_succeeded'].includes(event.type)&&s?.payment_status==='paid'){

  if(s.mode!=='payment'||s.currency!=='usd'||!/^cs_/.test(s.id)||!s.metadata?.invoice_id)throw fail('Unexpected payment',400);

  await db(env,'rpc/record_invoice_payment',{method:'POST',body:{event_key:event.id,invoice_key:s.metadata.invoice_id,session_key:s.id,paid_amount:s.amount_total,intent_key:typeof s.payment_intent==='string'?s.payment_intent:null}});

 }

 return json({received:true});

}

export default {

 async fetch(req,env){const url=new URL(req.url);

 if(url.protocol==='http:'&&url.hostname==='vznelite.org'){url.protocol='https:';return new Response(null,{status:308,headers:{Location:url.href,'Cache-Control':'no-store'}});}

 if(!url.pathname.startsWith('/api/'))return env.ASSETS.fetch(req);

 try{

  if(req.method!=='POST')return json({error:'Method not allowed'},405);

  if(Number(req.headers.get('content-length')||0)>262144)throw fail('Request too large',413);

  if(url.pathname==='/api/stripe-webhook')return await webhook(req,env);

  if(env.API_RATE_LIMIT){const {success}=await env.API_RATE_LIMIT.limit({key:req.headers.get('CF-Connecting-IP')||'unknown'});if(!success)return json({error:'Too many requests. Please wait a minute and try again.'},429);}

  if(['/api/checkout','/api/invoices'].includes(url.pathname))return json({error:'Card checkout is disabled. Use Venmo and report payment in your account.'},410);
  return json({error:'Not found'},404);
 }catch(e){console.error(JSON.stringify({event:'api_error',path:url.pathname,status:e.status||500}));return json({error:e.status?e.message:'Unable to complete this request'},e.status||500);}

 },

 async scheduled(controller,env,ctx){ctx.waitUntil((async()=>{try{await deliverNotifications(env);}catch{console.error(JSON.stringify({event:'account_notifications_failed'}));}await deliverTeamEmails(env,db);})());}

};

export async function deliverNotifications(env){

 if(env.NOTIFICATIONS_ENABLED!=='true')return;

 if(!env.RESEND_API_KEY||!env.MAIL_FROM)throw Error('Notification sender not configured');

 const notifications=await db(env,'rpc/claim_admin_notifications',{method:'POST',body:{}});

 for(const n of notifications){try{

  const roles=await db(env,'team_memberships?role=eq.administrator&select=user_id');

  const emails=[];for(const role of roles){const r=await fetch(env.SUPABASE_URL+'/auth/v1/admin/users/'+role.user_id,{headers:{apikey:env.SUPABASE_SERVICE_ROLE_KEY,Authorization:'Bearer '+env.SUPABASE_SERVICE_ROLE_KEY}});if(!r.ok)throw Error('Recipient lookup failed');const u=await r.json();if(u.email_confirmed_at&&u.email)emails.push(u.email);}

  if(!emails.length)throw Error('No verified administrators');

  // Separate messages preserve each administrator's email privacy. Stable keys deduplicate retries.

  for(const email of new Set(emails)){const r=await fetch('https://api.resend.com/emails',{method:'POST',headers:{Authorization:'Bearer '+env.RESEND_API_KEY,'Content-Type':'application/json','Idempotency-Key':'vzn-new-account-'+n.id+'-'+email},body:JSON.stringify({from:env.MAIL_FROM,to:[email],subject:'VZN Elite: new verified account',text:'A new verified account is ready for review. Sign in to Account access to review pending members and family requests.\n\n'+safeOrigin(env.NOTIFICATION_SITE_ORIGIN||env.SITE_ORIGIN)+'/#administration?section=access'})});if(!r.ok)throw Error('Email provider rejected message');}

  await db(env,'admin_notifications?id=eq.'+n.id,{method:'PATCH',body:{sent_at:new Date().toISOString(),last_error:null}});

 }catch{await db(env,'admin_notifications?id=eq.'+n.id,{method:'PATCH',body:{last_error:'Delivery failed; check sender configuration and administrator accounts.'}});console.error(JSON.stringify({event:'notification_failed',id:n.id}));}}

}

