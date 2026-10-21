const allTabs=[['families','Families'],['roster','Roster'],['schedule','Schedule'],['announcements','Announcements'],['billing','Player Contributions & sponsorships'],['finances','Finances'],['tournaments','Tournaments'],['access','Account access']];
export function mountWorkspaceTabs(section,{getActive,setActive,allowedKeys=null,label='Admin section',labels={}}){
 const tabs=allTabs.filter(([key])=>!allowedKeys||allowedKeys.includes(key)).map(([key,text])=>[key,labels[key]||text]);
 const wrapper=document.createElement('div');wrapper.className='workspace-navigation';
 const picker=document.createElement('label');picker.className='workspace-picker';picker.textContent=label;
 const select=document.createElement('select');select.setAttribute('aria-label',label);
 for(const [key,label] of tabs){const option=document.createElement('option');option.value=key;option.textContent=label;select.append(option);}picker.append(select);wrapper.append(picker);
 const nav=document.createElement('div');nav.className='workspace-tabs';nav.setAttribute('role','tablist');nav.setAttribute('aria-label',label);wrapper.append(nav);section.prepend(wrapper);
 function update(){if(!wrapper.isConnected)return;let active=getActive();if(!tabs.some(([key])=>key===active))active=tabs[0][0];select.value=active;
 for(const panel of section.querySelectorAll('[data-workspace]')){panel.hidden=panel.dataset.workspace!==active;panel.setAttribute('role','tabpanel');panel.setAttribute('aria-labelledby','workspace-tab-'+panel.dataset.workspace);}
 nav.innerHTML=tabs.map(([key,label])=>`<button role="tab" id="workspace-tab-${key}" aria-selected="${active===key}" tabindex="${active===key?'0':'-1'}" data-tab="${key}">${label}</button>`).join('');}
 select.addEventListener('change',event=>{event.stopPropagation();setActive(select.value);update();});
 nav.addEventListener('click',event=>{event.stopPropagation();const b=event.target.closest('[data-tab]');if(b){setActive(b.dataset.tab);update();nav.querySelector(`[data-tab="${getActive()}"]`).focus();}});
 nav.addEventListener('keydown',event=>{const index=tabs.findIndex(([key])=>key===getActive());let next;if(event.key==='ArrowRight')next=(index+1)%tabs.length;if(event.key==='ArrowLeft')next=(index+tabs.length-1)%tabs.length;if(event.key==='Home')next=0;if(event.key==='End')next=tabs.length-1;if(next!==undefined){event.preventDefault();setActive(tabs[next][0]);update();nav.querySelector(`[data-tab="${getActive()}"]`).focus();}});
 const observer=new MutationObserver(update);const cloud=section.querySelector('.cloud-team');if(cloud)observer.observe(cloud,{childList:true,subtree:true});
 update();return update;
}
