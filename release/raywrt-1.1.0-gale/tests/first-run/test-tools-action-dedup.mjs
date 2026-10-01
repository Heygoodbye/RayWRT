import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import vm from 'node:vm';

const candidates = [
	new URL('../../htdocs/luci-static/resources/view/raywrt/tools-v3.js', import.meta.url),
	new URL('../../package/luci-theme-raywrt/htdocs/luci-static/resources/view/raywrt/tools-v3.js', import.meta.url)
];
const sourcePath = process.argv[2] || candidates.find(path => existsSync(path));
assert.ok(sourcePath, 'tools.js source exists in the canonical tree or release bundle');
const source = readFileSync(sourcePath, 'utf8')
	.replace(/'require [^']+';/g, '')
	.replace('return view.extend({', 'globalThis.page = {')
	.replace(/\}\);\s*$/, '};');

function element(tagName, attributes, children) {
	return { tagName: tagName.toUpperCase(), attributes: attributes || {}, children: Array.isArray(children) ? children : [children] };
}

const sandbox = {
	view: { extend: value => value },
	E: element,
	L: { url: value => value },
	window: { setTimeout() {} },
	document: { addEventListener() {}, getElementById() { return null; } },
	ui: {},
	navigator: {},
	console
};
vm.runInNewContext(source, sandbox, { filename: 'tools.js' });

const passwall = { id: 'passwall2', name: 'Passwall 2', category: 'VPN & Proxy', description: 'Proxy and routing', route: 'admin/services/passwall2', packages: ['luci-app-passwall2'] };
sandbox.page.state = {};
let card = sandbox.page.card(passwall, true);
let actions = card.children[2].children;
assert.equal(actions.length, 1, 'unknown state renders one Retry, not duplicate actions');
assert.equal(actions[0].children[0], 'Retry');

const packageTools = [
	{ id: 'wireguard', name: 'WireGuard', category: 'VPN & Proxy', description: 'VPN', route: 'admin/raywrt-tools/wireguard', packages: ['luci-proto-wireguard', 'wireguard-tools', 'kmod-wireguard'] },
	{ id: 'xray', name: 'Xray Core', category: 'VPN & Proxy', description: 'Core', packages: ['xray-core'] },
	{ id: 'singbox', name: 'Sing-box', category: 'VPN & Proxy', description: 'Core', packages: ['sing-box'] },
	{ id: 'openvpn', name: 'OpenVPN', category: 'VPN & Proxy', description: 'VPN', route: 'admin/vpn/openvpn', packages: ['openvpn-openssl', 'luci-app-openvpn'] },
	{ id: 'terminal', name: 'Terminal', category: 'Advanced', description: 'Shell', route: 'admin/raywrt-tools/terminal', packages: ['ttyd'] }
];

for (const tool of packageTools) {
	sandbox.page.state = {};
	card = sandbox.page.card(tool);
	actions = card.children[2].children;
	assert.equal(actions.length, 1, `${tool.id} resolver failure gets one frontend-owned Retry`);
	assert.equal(actions[0].children[0], 'Retry');

	sandbox.page.state = { [`tool_${tool.id}`]: 'not_installed' };
	card = sandbox.page.card(tool);
	actions = card.children[2].children;
	assert.equal(actions.length, 1, `${tool.id} not-installed state gets one Install action`);
	assert.equal(actions[0].children[0], 'Install');

	sandbox.page.state = { [`tool_${tool.id}`]: 'installed', [`route_${tool.id}`]: 'yes' };
	card = sandbox.page.card(tool);
	actions = card.children[2].children;
	const labels = actions.map(action => action.children[0]);
	assert.equal(new Set(labels).size, labels.length, `${tool.id} has no duplicate semantic action labels`);
	if (tool.route) assert.ok(labels.includes(tool.id === 'wireguard' ? 'Configure' : 'Open'), `${tool.id} exposes its installed route`);
	else assert.ok(labels.includes('Manage'), `${tool.id} exposes package management without a route`);
	if (tool.id !== 'passwall2') assert.ok(labels.includes('Manage'), `${tool.id} keeps its package manager action`);
}

sandbox.page.state = { tool_wireguard: 'not_installed' };
const openvpn = packageTools.find(t => t.id === 'openvpn');
for (const route of ['admin/vpn/openvpn', 'admin/services/openvpn']) {
 sandbox.page.state = {tool_openvpn:'installed', route_openvpn:'yes', openvpn_route:route};
 const open = sandbox.page.card(openvpn).children[2].children.find(a => a.children[0] === 'Open');
 assert.equal(open.attributes.href, route, 'OpenVPN opens the detected native manager');
}
sandbox.page.state = { tool_wireguard: 'not_installed' };
card = sandbox.page.card(packageTools[0]);
assert.equal(card.children[2].children.length, 1, 'Quick Access and category cards share one action-rendering path');

sandbox.page.state = { tool_passwall2: 'not_installed' };
card = sandbox.page.card(passwall, true);
actions = card.children[2].children;
assert.equal(actions.length, 1, 'not-installed Passwall renders only its primary action');
assert.equal(actions[0].children[0], 'Install');

sandbox.page.state = { tool_passwall2: 'installed', route_passwall2: 'yes' };
card = sandbox.page.card(passwall, true);
actions = card.children[2].children;
assert.equal(actions.length, 1, 'installed Passwall renders only Open');
assert.equal(actions[0].children[0], 'Open');
assert.equal(actions[0].attributes.href, 'admin/services/passwall2', 'installed Passwall opens its actual manager route');
assert.equal(card.children[0].children[1].children[1].children[0], 'Installed · Not configured');

sandbox.page.state = { tool_passwall2: 'installed', route_passwall2: 'yes', passwall_configured: 'yes', passwall_runtime: 'stopped' };
card = sandbox.page.card(passwall, true);
assert.equal(card.children[0].children[1].children[1].children[0], 'Installed · Configured · Stopped');

sandbox.page.state = { tool_passwall2: 'installed', route_passwall2: 'yes', passwall_configured: 'yes', passwall_runtime: 'running' };
card = sandbox.page.card(passwall, true);
assert.equal(card.children[0].children[1].children[1].children[0], 'Running');

sandbox.page.state = { tool_passwall2: 'install_failed' };
card = sandbox.page.card(passwall, true);
actions = card.children[2].children;
assert.equal(actions.length, 1, 'incomplete installation renders one retry-install action');
assert.equal(actions[0].children[0], 'Retry install');
assert.equal(card.children[0].children[1].children[1].children[0], 'Install incomplete');

console.log('PASS: Passwall Quick Access handles unknown, install-failed, installed, configured-stopped and running states with one correct action.');

if (process.argv[3]) {
 const status = readFileSync(process.argv[3], 'utf8');
 sandbox.fs = { exec: async () => ({ code: 0, stdout: status, stderr: '' }) };
 let draws = 0;
 sandbox.page.draw = () => { draws++; };
 await sandbox.page.loadStatus(false);
 assert.equal(draws, 1, 'real backend status reaches rendering');
 assert.equal(sandbox.page.state.tool_passwall2, 'not_installed');
 assert.ok(['installed','not_installed'].includes(sandbox.page.state.tool_terminal));
 assert.equal(sandbox.page.state.tool_wireguard, 'installed');
 for (const tool of [passwall, ...packageTools]) {
  const card = sandbox.page.card(tool);
  const actions = card.children[2].children;
  const labels = actions.map(action => action.children[0]);
  assert.ok(!labels.includes('Retry'), `${tool.id} real backend state never degrades to Retry`);
  assert.equal(labels.length, new Set(labels).size, `${tool.id} real RPC output has unique actions`);
 }
 console.log('PASS: packaged Tools parses real live backend status and renders correct unique actions.');
}
