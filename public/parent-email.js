const esc=x=>String(x??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
export function mountParentEmail(container,{client,members,memberships,roles}){
 if(!roles.includes('administrator'))return;
 const parents=members.filter(m=>memberships.some(r=>r.user_id===m.id&&r.role==='parent'));
 const root=document.createElement('section');root.className='card finance-heading';root.dataset.workspace='email';
 root.innerHTML=`<h2>Email a parent</h2><p>Send one private email from notifications@vznelite.org to the selected parent's verified account email.</p><form class="finance-form"><label>Parent<select name="parent" required><option value="">Choose a parent</option>${parents.map(p=>`<option value="${esc(p.id)}">${esc(p.display_name)} (${esc(p.id.slice(0,8))})</option>`).join('')}</select></label><label>Subject<input name="subject" maxlength="150" required></label><label>Message<textarea name="message" rows="9" maxlength="8000" required></textarea></label><button class="quiet" type="button" data-contribution>Insert contribution link</button><button class="button" ${parents.length?'':'disabled'}>Review email</button><div data-review hidden><h3>Review before sending</h3><p data-recipient></p><strong data-subject></strong><p data-message style="white-space:pre-wrap;overflow-wrap:anywhere"></p><p>The parent's registered email is looked up securely when sending. Resend acceptance confirms submission; final delivery appears in Resend.</p><button type="button" class="button" data-send>Send email</button><button type="button" class="quiet" data-cancel>Keep editing</button></div></form><p role="status" aria-live="polite"></p>`;
 let busy=false,review=null,attempt=null;const form=root.querySelector('form'),status=root.querySelector('[role=status]'),panel=root.querySelector('[data-review]');
 const values=()=>{const d=new FormData(form);return {parentId:d.get('parent'),subject:String(d.get('subject')).trim(),message:String(d.get('message')).trim()};};
 const resetReview=()=>{review=null;panel.hidden=true;};
 form.addEventListener('input',resetReview);form.addEventListener('change',resetReview);
 form.addEventListener('submit',event=>{event.preventDefault();event.stopPropagation();if(busy)return;review=values();root.querySelector('[data-recipient]').textContent='To: '+parents.find(p=>p.id===review.parentId)?.display_name;root.querySelector('[data-subject]').textContent=review.subject;root.querySelector('[data-message]').textContent=review.message;panel.hidden=false;status.textContent='Review your message, then select Send email.';});
 root.addEventListener('click',async event=>{event.stopPropagation();const button=event.target.closest('button');if(!button||busy)return;
 if(button.hasAttribute('data-cancel')){resetReview();return;}
 if(button.hasAttribute('data-contribution')){form.elements.subject.value||= 'VZN Elite: player contribution';form.elements.message.value+='\n\nView your issued player contributions: https://vznelite.org/#contributions\nSign in with your parent account to review the amount for your linked player and month.';resetReview();return;}
 if(!button.hasAttribute('data-send')||!review)return;
 const payload={...review},fingerprint=JSON.stringify(payload);if(attempt?.fingerprint!==fingerprint)attempt={fingerprint,id:crypto.randomUUID()};
 busy=true;form.querySelectorAll('input,select,textarea,button').forEach(x=>x.disabled=true);status.textContent='Sending to Resend...';
 try{const session=await client.auth.getSession();if(session.error)throw session.error;const token=session.data.session?.access_token;if(!token)throw Error('Sign in again before sending.');
 const response=await fetch('/api/parent-email',{method:'POST',headers:{'Content-Type':'application/json',Authorization:'Bearer '+token},body:JSON.stringify({...payload,requestId:attempt.id})});const result=await response.json();if(!response.ok)throw Error(result.error||'Email could not be sent.');
 status.textContent=`Accepted by Resend for ${result.recipient}. Message ID: ${result.id}. Check Resend for delivery status.`;attempt=null;form.reset();resetReview();
 }catch(error){status.textContent=error.message+' No successful send has been confirmed.';}
 finally{busy=false;form.querySelectorAll('input,select,textarea,button').forEach(x=>x.disabled=false);}
 });container.append(root);
}
