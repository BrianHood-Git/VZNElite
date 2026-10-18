import {verifyStripeSignature,validateCheckoutInvoice,safeOrigin,limitedBody} from './security.js';
const json=(data,status=200)=>Response.json(data,{status,headers:{'Cache-Control':'no-store','X-Content-Type-Options':'nosniff'}});
const fail=(message,status=400)=>Object.assign(Error(message),{status});
async function db(env,path,{token,method='GET',body}={}){
 const key=token?env.SUPABASE_PUBLISHABLE_KEY:env.SUPABASE_SERVICE_ROLE_KEY;if(!key)throw fail('Server setup is incomplete',503);
 const r=await fetch(env.SUPABASE_URL+'/rest/v1/'+path,{method,headers:{apikey:key,Authorization:'Bearer '+(token||key),'Content-Type':'application/json',Prefer:'return=representation'},body:body===undefined?undefined:JSON.stringify(body)});
 if(!r.ok)throw fail('Database operation failed',502);return r.status===204?null:r.json();
}
async function auth(req,env){const token=req.headers.get('Authorization')?.match(/^Bearer (\S+)$/)?.[1];if(!token)throw fail('Sign in required',401);const r=await fetch(env.SUPABASE_URL+'/auth/v1/user',{headers:{apikey:env.SUPABASE_PUBLISHABLE_KEY,Authorization:'Bearer '+token}});if(!r.ok)throw fail('Please sign in again',401);const user=await r.json();if(!user.email_confirmed_at)throw fail('Verify your email first',403);return {user,token};}
async function stripe(env,path,body,key){const r=await fetch('https://api.stripe.com/v1/'+path,{method:body?'POST':'GET',headers:{Authorization:'Bearer '+env.STRIPE_SECRET_KEY,...(body?{'Content-Type':'application/x-www-form-urlencoded'}:{}),...(key?{'Idempotency-Key':key}:{})},body:body?new URLSearchParams(body):undefined});const data=await r.json();if(!r.ok)throw fail('Stripe is temporarily unavailable. No payment status was changed.',502);return data;}
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
 async fetch(req,env){const url=new URL(req.url);if(!url.pathname.startsWith('/api/'))return env.ASSETS.fetch(req);
 try{
  if(req.method!=='POST')return json({error:'Method not allowed'},405);
  if(Number(req.headers.get('content-length')||0)>262144)throw fail('Request too large',413);
  if(url.pathname==='/api/stripe-webhook')return await webhook(req,env);
  if(!['/api/invoices','/api/checkout'].includes(url.pathname))return json({error:'Not found'},404);
  const origin=safeOrigin(env.SITE_ORIGIN);if(req.headers.get('Origin')!==origin)throw fail('Origin not allowed',403);
  const {user,token}=await auth(req,env);const raw=await limitedBody(req,4096);let body;try{body=JSON.parse(raw);}catch{throw fail('Invalid request body');}if(!body||typeof body!=='object')throw fail('Invalid request body');
  if(url.pathname==='/api/invoices'){
   if(!/^\d{4}-\d{2}-01$/.test(body.period||'')||!/^[-a-f0-9]{36}$/i.test(body.player_id||''))throw fail('Choose a player and billing month');
   const roles=await db(env,'team_memberships?select=role&user_id=eq.'+user.id,{token});if(!roles.some(r=>r.role==='administrator'))throw fail('Administrator access required',403);
   return json(await db(env,'rpc/issue_monthly_invoice',{token,method:'POST',body:{player_key:body.player_id,billing_month:body.period}}));
  }
  if(env.PAYMENTS_ENABLED!=='true'||!env.STRIPE_SECRET_KEY)throw fail('Payments are not enabled yet. No charge was made.',503);
  if(!/^[-a-f0-9]{36}$/i.test(body.invoice_id||''))throw fail('Invalid invoice');
  const invoice=(await db(env,'billing_invoices?id=eq.'+body.invoice_id+'&select=*',{token}))[0];validateCheckoutInvoice(invoice,user.id);
  let prior=null;if(invoice.checkout_session_id){prior=await stripe(env,'checkout/sessions/'+encodeURIComponent(invoice.checkout_session_id));if(prior.status==='open'&&prior.url)return json({url:prior.url});if(prior.status==='complete')throw fail('Payment is processing. Refresh your account shortly.',409);}
  const session=await stripe(env,'checkout/sessions',{
   mode:'payment','payment_method_types[0]':'card',customer_email:user.email,client_reference_id:invoice.id,'metadata[invoice_id]':invoice.id,
   'line_items[0][price_data][currency]':'usd','line_items[0][price_data][unit_amount]':String(invoice.amount_cents),'line_items[0][price_data][product_data][name]':'VZN Elite dues · '+invoice.period.slice(0,7),'line_items[0][quantity]':'1',
   success_url:origin+'/?payment=processing#account',cancel_url:origin+'/#account'
  },'vzn-invoice-'+invoice.id+'-'+(prior?.id||'first'));
  const saved=await db(env,'billing_invoices?id=eq.'+invoice.id+'&status=eq.open',{method:'PATCH',body:{checkout_session_id:session.id}});
  if(saved?.length!==1)throw fail('Invoice changed. Refresh your account.',409);
  return json({url:session.url});
 }catch(e){console.error(JSON.stringify({event:'api_error',path:url.pathname,status:e.status||500}));return json({error:e.status?e.message:'Unable to complete this request'},e.status||500);}
 },
 async scheduled(controller,env,ctx){ctx.waitUntil(deliverNotifications(env));}
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
  for(const email of new Set(emails)){const r=await fetch('https://api.resend.com/emails',{method:'POST',headers:{Authorization:'Bearer '+env.RESEND_API_KEY,'Content-Type':'application/json','Idempotency-Key':'vzn-new-account-'+n.id+'-'+email},body:JSON.stringify({from:env.MAIL_FROM,to:[email],subject:'VZN Elite: new verified account',text:'A new verified account is ready for review. Sign in to Account access to review pending members and family requests.\n\n'+safeOrigin(env.NOTIFICATION_SITE_ORIGIN||env.SITE_ORIGIN)+'/#account'})});if(!r.ok)throw Error('Email provider rejected message');}
  await db(env,'admin_notifications?id=eq.'+n.id,{method:'PATCH',body:{sent_at:new Date().toISOString(),last_error:null}});
 }catch{await db(env,'admin_notifications?id=eq.'+n.id,{method:'PATCH',body:{last_error:'Delivery failed; check sender configuration and administrator accounts.'}});console.error(JSON.stringify({event:'notification_failed',id:n.id}));}}
}
