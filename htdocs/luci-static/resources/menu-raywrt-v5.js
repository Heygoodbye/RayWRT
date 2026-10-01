'use strict';
'require baseclass';
'require ui';

return baseclass.extend({
 __init__() { ui.menu.load().then(tree => this.render(tree)); },
 render(tree) {
  const modes = ui.menu.getChildren(tree);
  const top = document.getElementById('topmenu');
  const modeMenu = document.getElementById('modemenu');
  const active = L.env.requestpath[0] || 'admin';
  let entries = [];
  modes.forEach(mode => {
   const a = E('a', { href: L.url(mode.name) }, _(mode.title));
   modeMenu.appendChild(E('li', { class: mode.name === active ? 'active' : '' }, a));
   if (mode.name !== active) return;
   ui.menu.getChildren(mode).forEach(section => {
    if (section.name === 'raywrt' || section.name === 'logout') return;
    const children = ui.menu.getChildren(section);
    const path = mode.name + '/' + section.name;
    const activeSection = L.env.requestpath[1] === section.name;
    const key = 'raywrt-section-' + section.name;
    const open = activeSection || sessionStorage.getItem(key) === '1';
    const group = E('li', { class: 'rw-nav-group' + (activeSection ? ' active' : '') + (open ? ' rw-expanded' : '') });
    const label = [E('span', { class: 'rw-nav-icon' }, this.icon(section.name)),
     E('span', { class: 'rw-nav-label' }, _(section.title)), E('span', { class: 'rw-nav-chevron', 'aria-hidden': 'true' }, '›')];
    if (children.length) {
     const toggle = E('button', { type: 'button', class: 'rw-nav-link', 'aria-label': _(section.title), 'aria-expanded': open ? 'true' : 'false' }, label);
     toggle.addEventListener('click', () => {
      const expanded = group.classList.toggle('rw-expanded');
      toggle.setAttribute('aria-expanded', expanded ? 'true' : 'false');
      sessionStorage.setItem(key, expanded ? '1' : '0');
     });
     group.appendChild(toggle);
     const sub = E('ul', { class: 'rw-submenu' });
     children.forEach(child => {
      const childPath = path + '/' + child.name;
      sub.appendChild(E('li', { class: L.env.requestpath.join('/').startsWith(childPath) ? 'active' : '' },
       E('a', { href: L.url(childPath) }, _(child.title))));
      entries.push({ title: _(child.title), section: _(section.title), href: L.url(childPath) });
     });
     group.appendChild(sub);
    } else group.appendChild(E('a', { href: L.url(path), class: 'rw-nav-link' }, label));
    top.appendChild(group);
    entries.push({ title: _(section.title), section: '', href: L.url(path) });
   });
  });
  top.style.display = modeMenu.style.display = '';
  const hasNativeTabs = this.tabs(tree);
  if (!hasNativeTabs) this.passwallMenu();
  const search = document.getElementById('rw-search'), results = document.getElementById('rw-search-results');
  search.addEventListener('input', () => {
   const q = search.value.trim().toLocaleLowerCase();
   results.replaceChildren();
   if (!q) { results.hidden = true; return; }
   entries.filter(x => (x.title + ' ' + x.section).toLocaleLowerCase().includes(q)).slice(0, 12).forEach(x =>
    results.appendChild(E('a', { href: x.href, role: 'option' }, [x.title, x.section ? E('small', {}, x.section) : ''])));
   results.hidden = !results.childElementCount;
  });
  search.addEventListener('keydown', ev => { if (ev.key === 'Escape') { search.value = ''; results.hidden = true; } });
  document.addEventListener('click', ev => { if (!ev.target.closest('.rw-search-wrap,#rw-search-results')) results.hidden = true; });
  const setOpen=open=>{document.body.classList.toggle('rw-nav-open',open);document.querySelectorAll('.rw-mobile-toggle,.rw-more-toggle').forEach(b=>b.setAttribute('aria-expanded',open));};
  document.querySelectorAll('.rw-mobile-toggle,.rw-more-toggle').forEach(b=>b.addEventListener('click',()=>setOpen(!document.body.classList.contains('rw-nav-open'))));
  document.addEventListener('click',ev=>{
   if(window.matchMedia('(max-width: 850px)').matches&&document.body.classList.contains('rw-nav-open')&&!ev.target.closest('.rw-sidebar,.rw-more-toggle,.rw-mobile-toggle'))setOpen(false);
  });
  document.addEventListener('keydown',ev=>{
   if(ev.key==='Escape'&&document.body.classList.contains('rw-nav-open'))setOpen(false);
  });
  const collapsed=localStorage.getItem('raywrt-nav-collapsed')==='1';
  document.body.classList.toggle('rw-collapsed',collapsed);
  const collapse=document.querySelector('.rw-collapse-toggle');
  collapse.setAttribute('aria-expanded',!collapsed);
  collapse.addEventListener('click',()=>{const value=document.body.classList.toggle('rw-collapsed');localStorage.setItem('raywrt-nav-collapsed',value?'1':'0');collapse.setAttribute('aria-expanded',!value);collapse.setAttribute('aria-label',value?'Expand navigation':'Collapse navigation');});
  const path=L.env.requestpath.join('/');
  document.querySelectorAll('.rw-primary a,.rw-bottom-nav a').forEach(a=>{
   const target=new URL(a.href).pathname.split('/cgi-bin/luci/')[1];
   if(target&&path===target)a.classList.add('active');
  });
 },
 passwallMenu() {
  const path = location.pathname.split('/cgi-bin/luci/')[1] || '';
  if (!path.startsWith('admin/services/passwall2')) return;
  const links = [
   ['Passwall Home','admin/services/passwall2'], ['Node List','admin/services/passwall2/node_list'],
   ['Node Subscribe','admin/services/passwall2/node_subscribe'], ['App Update','admin/services/passwall2/app_update'],
   ['Rule Manage','admin/services/passwall2/rule'], ['Access Control','admin/services/passwall2/acl'],
   ['Runtime Logs','admin/services/passwall2/log'], ['Other Settings','admin/services/passwall2/other']
  ];
  const container = document.getElementById('tabmenu');
  const list = E('ul', { class: 'tabs rw-passwall-tabs', 'aria-label': 'Passwall 2 navigation' });
  links.forEach(([title, target]) => list.appendChild(E('li', { class: path === target || (target !== 'admin/services/passwall2' && path.startsWith(target + '/')) ? 'active' : '' }, E('a', { href: L.url(target) }, title))));
  container.appendChild(list);
  container.style.display = '';
 },
 icon(name) { return ({'raywrt-tools':'✦',status:'⌁',network:'◎',services:'▤',system:'⚙',vpn:'◇'})[name] || '▦'; },
 tabs(tree) {
  let node = tree, url = '';
  for (let i = 0; i < 3 && node; i++) { node = node.children?.[L.env.dispatchpath[i]]; url += (url ? '/' : '') + L.env.dispatchpath[i]; }
  const container = document.getElementById('tabmenu');
  let level = 3, rendered = false;
  while (node && level < 8) {
   const children = ui.menu.getChildren(node);
   if (!children.length) break;
   rendered = true;
   const ul = E('ul', { class: 'tabs' });
   children.forEach(child => ul.appendChild(E('li', { class: L.env.dispatchpath[level] === child.name ? 'active' : '' },
    E('a', { href: L.url(url, child.name) }, _(child.title)))));
   container.appendChild(ul); container.style.display = '';
   const next = L.env.dispatchpath[level++]; node = next ? node.children?.[next] : null; url += '/' + next;
  }
  return rendered;
 }
});
