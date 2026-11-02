import {mountAnnouncements} from './announcements.js?v=20261021-venmo';
import {saveVersionedDocument} from './cloud-data.js?v=20261021-venmo';
export async function mountAdminAnnouncements(container,{client}){
 const host=document.createElement('div');host.dataset.workspace='announcements';container.append(host);
 const notice=document.createElement('p');notice.setAttribute('role','status');notice.setAttribute('aria-live','polite');host.append(notice);
 const report=document.createElement('div');host.append(report);
 const slot=document.createElement('div');host.append(slot);let locked=false;
 try{
  const {data:doc,error}=await client.from('team_documents').select('*').eq('key','announcements').single();if(error)throw error;
  const {data:deliveryRows}=await client.from('team_email_outbox').select('kind,sent_at,attempts,expires_at,last_error').order('created_at',{ascending:false}).limit(50);
  if(deliveryRows){const sent=deliveryRows.filter(r=>r.sent_at).length,pending=deliveryRows.filter(r=>!r.sent_at&&r.attempts<10&&new Date(r.expires_at)>new Date()).length;report.textContent='Recent email deliveries: '+sent+' accepted by provider; '+pending+' pending. Practice reminders send at 6 p.m. Central the day before each practice.';}
  const state={announcements:doc.data.items||[]};let version=doc.version;
  mountAnnouncements(slot,{state,isStaff:()=>true,toast:text=>notice.textContent=text,save:async()=>{
   if(locked)return false;locked=true;slot.inert=true;
   try{version=await saveVersionedDocument(client,'announcements',{items:state.announcements},version);return true;}
   catch(err){notice.textContent='Not saved: '+err.message;return false;}
   finally{locked=false;slot.inert=false;}
  }});
 }catch(err){notice.textContent='Could not load announcements: '+err.message;}
}
