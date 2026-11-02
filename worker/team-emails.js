import {safeOrigin} from './security.js';
export async function deliverTeamEmails(env,db){
 if(env.TEAM_EMAILS_ENABLED!=='true')return;
 if(!env.RESEND_API_KEY||!env.MAIL_FROM)throw Error('Team email sender not configured');
 const rows=await db(env,'rpc/claim_team_emails',{method:'POST',body:{}});
 for(const [index,n] of rows.entries()){
  // Resend's default API limit is shared with the existing account notifications.
  if(index)await new Promise(resolve=>setTimeout(resolve,650));
  try{
   const response=await fetch('https://api.resend.com/emails',{method:'POST',headers:{Authorization:'Bearer '+env.RESEND_API_KEY,'Content-Type':'application/json','Idempotency-Key':'vzn-team-'+n.id},body:JSON.stringify({from:env.MAIL_FROM,to:[n.email],subject:n.subject,text:n.message+'\n\nView your team workspace:\n'+safeOrigin(env.NOTIFICATION_SITE_ORIGIN||env.SITE_ORIGIN)+'/#'+(n.kind==='practice'?'schedule':'account')})});
   if(!response.ok)throw Error('Provider rejected message');
   await db(env,'team_email_outbox?id=eq.'+n.id,{method:'PATCH',body:{sent_at:new Date().toISOString(),last_error:null}});
  }catch{
   await db(env,'team_email_outbox?id=eq.'+n.id,{method:'PATCH',body:{last_error:'Email delivery failed; automatic retry pending.'}});
   console.error(JSON.stringify({event:'team_email_failed',id:n.id}));
  }
 }
}
