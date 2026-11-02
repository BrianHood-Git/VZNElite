const origin='https://vznelite.org';
const escape=x=>String(x).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
export function sharingContent(kind){
 if(kind==='parent')return {title:'Join VZN Elite as a parent',url:origin+'/#register',text:'You are invited to join VZN Elite as a parent or guardian. Create your own parent account at '+origin+'/#register'+', verify your email, and request a link to your child in Family setup. A team administrator will review your request. Already registered? Sign in with your existing account instead of creating another one. Registration does not automatically grant player access.'};
 if(kind==='contribution')return {title:'VZN Elite player contributions',url:origin+'/#contributions',text:'View your VZN Elite player contributions at '+origin+'/#contributions'+'. Sign in with your parent account and use the amount shown for the issued month. A linked player is required before the Venmo option is available. After paying in Venmo, report the payment in your account for administrator verification. Opening the link does not mark a payment as received.'};
 throw Error('Unknown sharing action');
}
export function mountAdminSharing(container,{roles}){
 if(!roles.includes('administrator'))return;
 for(const kind of ['parent','contribution']){
  const content=sharingContent(kind),root=document.createElement('section');root.className='card finance-heading';root.dataset.workspace=kind==='parent'?'families':'billing';let busy=false;
  root.innerHTML=`<h2>${kind==='parent'?'Invite a parent':'Share contributions'}</h2><p>${kind==='parent'?'Share a registration invitation with a parent or guardian. Staff will still review family access requests.':'Share the account contribution page. The recipient must sign in and have a linked player; this does not bypass payment eligibility.'}</p><button class="button" type="button" data-open>${kind==='parent'?'Invite parent':'Share contribution link'}</button><div data-sharing-details hidden><label>Shareable link<input type="url" readonly value="${content.url}"></label><label>Message to share<textarea readonly rows="7">${escape(content.text)}</textarea></label><div class="actions"><button class="quiet" type="button" data-copy>Copy ${kind==='parent'?'invitation':'contribution message'}</button><button class="quiet" type="button" data-share>Share\u2026</button><a class="quiet" href="mailto:?subject=${encodeURIComponent(content.title)}&amp;body=${encodeURIComponent(content.text)}">Open email draft</a></div><p>No message is sent automatically. Choose the recipient in your messaging or email app.</p></div><p role="status" aria-live="polite"></p>`;
  root.addEventListener('click',async event=>{event.stopPropagation();const button=event.target.closest('button');if(!button||busy)return;const details=root.querySelector('[data-sharing-details]'),status=root.querySelector('[role=status]'),message=root.querySelector('textarea');
   if(button.hasAttribute('data-open')){details.hidden=!details.hidden;button.setAttribute('aria-expanded',String(!details.hidden));if(!details.hidden)message.focus();return;}
   busy=true;button.disabled=true;
   try{if(button.hasAttribute('data-share')&&typeof navigator.share==='function'){await navigator.share({title:content.title,text:content.text});status.textContent='Share dialog completed.';}else{if(!navigator.clipboard?.writeText)throw Error('Clipboard unavailable');await navigator.clipboard.writeText(content.text);status.textContent='Copied. Paste into the message you want to send.';}}
   catch(error){if(error.name==='AbortError')status.textContent='Sharing cancelled.';else{message.focus();message.select();status.textContent='Copy the selected message, or use Open email draft.';}}
   finally{busy=false;button.disabled=false;}
  });container.append(root);
 }
}
