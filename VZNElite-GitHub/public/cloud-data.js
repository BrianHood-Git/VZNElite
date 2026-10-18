export async function saveVersionedDocument(client,key,data,version){
 const result=await client.from('team_documents').update({data,version:version+1,updated_at:new Date().toISOString()}).eq('key',key).eq('version',version).select('version');
 if(result.error)throw result.error;
 if(result.data?.length!==1)throw Error('Another administrator changed this section. Refresh shared data before trying again.');
 return result.data[0].version;
}
