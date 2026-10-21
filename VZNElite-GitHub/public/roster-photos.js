export async function mountRosterPhotos(container,{client,user,staff}){
 const {data:links,error}=await client.from('family_links').select('player_id').eq('user_id',user.id);
 if(error)throw error;
 await Promise.all([...container.querySelectorAll('[data-roster-photo]')].map(async card=>{
  const id=card.dataset.rosterPhoto,path='players/'+id+'/avatar.jpg';
  card.classList.add('roster-player');
  const face=document.createElement('div');face.className='basketball-card';
  const top=document.createElement('div');top.className='basketball-card-top';top.innerHTML='<span>VZN <b>ELITE</b></span><span>2030</span>';face.append(top);
  const preview=document.createElement('div');preview.className='roster-photo';
  const placeholder=()=>{const logo=document.createElement('img');logo.src='/assets/logo.png';logo.alt='VZN Elite team logo';logo.className='roster-default-logo';preview.replaceChildren(logo);};
  placeholder();face.append(preview);
  const info=document.createElement('div');info.className='basketball-card-info';for(const node of [...card.children])if(node.matches('.tag,h3,p'))info.append(node);face.append(info);
  const footer=document.createElement('div');footer.className='basketball-card-footer';footer.textContent='SAN ANTONIO / CLASS OF 2030';face.append(footer);card.prepend(face);
  async function load(){const {data,error}=await client.storage.from('team-photos').createSignedUrl(path,300);if(error||!card.isConnected)return;const img=document.createElement('img');img.alt=card.querySelector('h3').textContent+' roster photo';img.src=data.signedUrl;img.onerror=placeholder;preview.replaceChildren(img);}
  await load();if(!card.isConnected||(!staff&&!links.some(l=>l.player_id===id)))return;
  const label=document.createElement('label');label.textContent='Upload / replace player photo (up to 5 MB)';const input=document.createElement('input');input.type='file';input.accept='image/jpeg,image/png,image/webp';label.append(input);card.append(label);
  const status=document.createElement('p');status.setAttribute('role','status');card.append(status);
  input.addEventListener('change',async()=>{const file=input.files[0];if(!file)return;input.disabled=true;try{if(!['image/jpeg','image/png','image/webp'].includes(file.type)||file.size>5242880)throw Error('Choose a JPG, PNG, or WebP under 5 MB.');status.textContent='Saving photo...';const bitmap=await createImageBitmap(file);const canvas=document.createElement('canvas');const scale=Math.min(1,1200/Math.max(bitmap.width,bitmap.height));canvas.width=Math.round(bitmap.width*scale);canvas.height=Math.round(bitmap.height*scale);canvas.getContext('2d').drawImage(bitmap,0,0,canvas.width,canvas.height);bitmap.close();const blob=await new Promise(resolve=>canvas.toBlob(resolve,'image/jpeg',.88));if(!blob)throw Error('Could not prepare this image');const {error}=await client.storage.from('team-photos').upload(path,blob,{upsert:true,contentType:'image/jpeg'});if(error)throw error;await load();status.textContent='Roster photo saved. Visible only to approved team members.';}catch(e){status.textContent=e.message;}finally{input.disabled=false;input.value='';}});
 }));
}
