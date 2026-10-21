export function mountMobileNavigation(header){
 const toggle=header?.querySelector('.nav-toggle');if(!toggle)return;
 const close=()=>{header.removeAttribute('data-menu-open');toggle.setAttribute('aria-expanded','false');};
 toggle.addEventListener('click',()=>{const open=toggle.getAttribute('aria-expanded')!=='true';toggle.setAttribute('aria-expanded',String(open));if(open)header.setAttribute('data-menu-open','true');else close();});
 header.addEventListener('click',event=>{if(event.target.closest('a'))close();});
 document.addEventListener('click',event=>{if(!header.contains(event.target))close();});
 document.addEventListener('keydown',event=>{if(event.key==='Escape'&&toggle.getAttribute('aria-expanded')==='true'){close();toggle.focus();}});
 window.addEventListener('hashchange',close);
}
