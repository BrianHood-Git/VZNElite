import test from 'node:test';
import assert from 'node:assert/strict';
import {saveVersionedDocument} from './public/cloud-data.js';
const fake=result=>{const filters=[];let update;const query={update(v){update=v;return this},eq(k,v){filters.push([k,v]);return this},select(){return Promise.resolve(result)}};return {client:{from(name){assert.equal(name,'team_documents');return query;}},filters,get update(){return update}};};
test('document save compares expected version before advancing it',async()=>{const db=fake({data:[{version:4}],error:null});assert.equal(await saveVersionedDocument(db.client,'dues',{monthly:10000},3),4);assert.deepEqual(db.filters,[['key','dues'],['version',3]]);assert.equal(db.update.version,4);});
test('stale or forbidden updates are not reported as saved',async()=>{await assert.rejects(saveVersionedDocument(fake({data:[]}).client,'finances',{},1),/Another administrator/);await assert.rejects(saveVersionedDocument(fake({error:Error('Access denied')}).client,'finances',{},1),/Access denied/);});
