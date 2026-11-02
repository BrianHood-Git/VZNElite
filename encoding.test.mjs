import test from 'node:test';import assert from 'node:assert/strict';import {readFile,readdir} from 'node:fs/promises';
test('first-party JavaScript uses encoding-safe Unicode escapes',async()=>{for(const file of await readdir('public')){if(!file.endsWith('.js'))continue;assert.doesNotMatch(await readFile('public/'+file,'utf8'),/[^\x00-\x7f]/,file+' contains raw non-ASCII source');}});
test('account loading message is plain ASCII',async()=>{const source=await readFile('public/account.js','utf8');assert.match(source,/<p role="status">Loading\.\.\.<\/p>/);});
