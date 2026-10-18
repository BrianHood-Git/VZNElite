const tabs=[['families','Families'],['roster','Roster'],['schedule','Schedule'],['announcements','Announcements'],['billing','Dues & sponsorships'],['finances','Finances'],['access','Account access'],['account','My account']];
export function mountWorkspaceTabs(section,{getActive,setActive}){
 const nav=document.createElement('div');nav.className='workspace-tabs';nav.setAttribute('role','tablist');nav.setAttribute('aria-label','Administrator responsibilities');section.prepend(nav);
 function update(){if(!nav.isConnected)return;let active=getActive();if(!tabs.some(([key])=>key===active))active='families';
 for(const panel of section.querySelectorAll('[data-workspace]')){panel.hidden=panel.dataset.workspace!==active;panel.setAttribute('role','tabpanel');panel.setAttribute('aria-labelledby','workspace-tab-'+panel.dataset.workspace);}
 nav.innerHTML=tabs.map(([key,label])=>`<button role="tab" id="workspace-tab-${key}" aria-selected="${active===key}" tabindex="${active===key?'0':'-1'}" data-tab="${key}">${label}</button>`).join('');}
 nav.addEventListener('click',e=>{e.stopPropagation();const b=e.target.closest('[data-tab]');if(b){setActive(b.dataset.tab);update();nav.querySelector(`[data-tab="${getActive()}"]`).focus();}});
 nav.addEventListener('keydown',e=>{const index=tabs.findIndex(([key])=>key===getActive());let next;if(e.key==='ArrowRight')next=(index+1)%tabs.length;if(e.key==='ArrowLeft')next=(index+tabs.length-1)%tabs.length;if(e.key==='Home')next=0;if(e.key==='End')next=tabs.length-1;if(next!==undefined){e.preventDefault();setActive(tabs[next][0]);update();nav.querySelector(`[data-tab="${getActive()}"]`).focus();}});
 const observer=new MutationObserver(update);observer.observe(section,{childList:true,subtree:true,attributeFilter:['data-workspace']});
 // Tab buttons are rebuilt by update; do not observe the navigation itself.
 observer.disconnect();const cloud=section.querySelector('.cloud-team');if(cloud)observer.observe(cloud,{childList:true,subtree:true});
 update();return update;
}
