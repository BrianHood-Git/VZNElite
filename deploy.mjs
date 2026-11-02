import {readFile} from 'node:fs/promises';
import {spawnSync} from 'node:child_process';
const config=JSON.parse(await readFile(new URL('./wrangler.jsonc',import.meta.url),'utf8'));
if(!/^[a-f0-9]{32}$/.test(config.account_id||''))throw Error('Set the confirmed VZN Elite Cloudflare account_id before deploying.');
if(config.account_id==='edf0232cb52cad957d75a24d398b0349')throw Error('The source personal Cloudflare account is blocked. Use the team account.');
if(config.vars.SITE_ORIGIN!=='https://vznelite.org')throw Error('Confirm the production site origin.');
const result=spawnSync(process.execPath,['node_modules/wrangler/bin/wrangler.js','deploy'],{cwd:new URL('.',import.meta.url),stdio:'inherit'});
process.exit(result.status??1);
