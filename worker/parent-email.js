import {limitedBody,safeOrigin} from './security.js';
const fail=(message,status)=>Object.assign(Error(message),{status});
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
export async function sendParentEmail(req,env,db){
 if(req.headers.get('Origin')!==safeOrigin(env.SITE_ORIGIN))throw fail('Refresh the website and try again.',403);
 const token=req.headers.get('Authorization')?.match(/^Bearer (\S+)$/)?.[1];
 if(!token)throw fail('Sign in before sending email.',401);
 const auth=await fetch(env.SUPABASE_URL+'/auth/v1/user',{headers:{apikey:env.SUPABASE_PUBLISHABLE_KEY,Authorization:'Bearer '+token}});
 if(!auth.ok)throw fail('Your session expired. Sign in again.',401);
 const actor=await auth.json();if(!uuid.test(actor.id||'')||!actor.email_confirmed_at)throw fail('Verified administrator access required.',403);
 const roles=await db(env,'team_memberships?user_id=eq.'+actor.id+'&role=eq.administrator&select=user_id');
 if(!roles.length)throw fail('Administrator access required.',403);
 if(env.API_RATE_LIMIT){const result=await env.API_RATE_LIMIT.limit({key:'parent-email:'+actor.id});if(!result.success)throw fail('Too many messages. Wait a minute before retrying.',429);}
 let input;try{input=JSON.parse(await limitedBody(req,20000));}catch(e){if(e.status)throw e;throw fail('Invalid email request.',400);}
 const {parentId,requestId}=input||{},subject=String(input?.subject||'').trim(),message=String(input?.message||'').trim();
 if(!uuid.test(parentId||'')||!uuid.test(requestId||'')||!subject||subject.length>150||/[\r\n]/.test(subject)||!message||message.length>8000)throw fail('Choose a parent and enter a subject (150 characters maximum) and message (8,000 maximum).',400);
 const parents=await db(env,'team_memberships?user_id=eq.'+parentId+'&role=eq.parent&select=user_id');
 if(!parents.length)throw fail('This member no longer has a parent role. Refresh the page.',409);
 if(env.TEAM_EMAILS_ENABLED!=='true'||!env.RESEND_API_KEY||!env.MAIL_FROM)throw fail('Email sending is not configured.',503);
 const recipient=await fetch(env.SUPABASE_URL+'/auth/v1/admin/users/'+parentId,{headers:{apikey:env.SUPABASE_SERVICE_ROLE_KEY,Authorization:'Bearer '+env.SUPABASE_SERVICE_ROLE_KEY}});
 if(!recipient.ok)throw fail('Unable to find the parent email. Try again.',502);
 const parent=await recipient.json();if(!parent.email||!parent.email_confirmed_at||parent.banned_until&&new Date(parent.banned_until)>new Date())throw fail('The parent needs a verified, active email account.',409);
 const response=await fetch('https://api.resend.com/emails',{method:'POST',headers:{Authorization:'Bearer '+env.RESEND_API_KEY,'Content-Type':'application/json','Idempotency-Key':'vzn-parent-'+actor.id+'-'+requestId},body:JSON.stringify({from:env.MAIL_FROM,to:[parent.email],subject,text:message+'\n\nVZN Elite\n'+safeOrigin(env.SITE_ORIGIN)+'/#account'})});
 if(!response.ok)throw fail('Resend did not accept the email. Retry the unchanged message to avoid duplicates.',502);
 const result=await response.json();if(!result.id)throw fail('Email confirmation unavailable. Retry the unchanged message.',502);
 console.log(JSON.stringify({event:'parent_email_accepted',actor:actor.id,parent:parentId,id:result.id}));
 return {id:result.id,recipient:parent.email,status:'accepted'};
}
