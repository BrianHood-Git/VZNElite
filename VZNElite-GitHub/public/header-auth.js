export async function mountHeaderAuth(link,{client,onSignedOut,onError}){
 let signedIn=false,busy=false,revision=0;
 const update=session=>{signedIn=Boolean(session?.user);link.textContent=signedIn?'Sign out':'Sign in ↗';link.setAttribute('aria-label',signedIn?'Sign out of your account':'Sign in to your account');};
 const {data:{subscription}}=client.auth.onAuthStateChange((event,session)=>{revision++;update(session);if(event==='SIGNED_OUT')queueMicrotask(onSignedOut);});
 const initialRevision=revision;
 const {data,error}=await client.auth.getSession();if(!error&&revision===initialRevision)update(data.session);
 link.addEventListener('click',async event=>{
  if(!signedIn)return;
  event.preventDefault();if(busy)return;busy=true;link.setAttribute('aria-busy','true');
  try{const {error}=await client.auth.signOut({scope:'local'});if(error)throw error;}catch(error){onError(error.message||'Unable to sign out. Please try again.');}finally{busy=false;link.removeAttribute('aria-busy');}
 });
 return ()=>subscription.unsubscribe();
}
