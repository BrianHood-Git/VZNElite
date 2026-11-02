export async function verifyStripeSignature(raw,header,secret,now=Date.now()){
 if(!header||!secret)return false;
 const parts=header.split(',').map(x=>x.split('='));const timestamp=parts.find(([k])=>k==='t')?.[1];
 if(!/^\d+$/.test(timestamp||'')||Math.abs(now/1000-Number(timestamp))>300)return false;
 const key=await crypto.subtle.importKey('raw',new TextEncoder().encode(secret),{name:'HMAC',hash:'SHA-256'},false,['verify']);
 for(const [kind,value] of parts){if(kind!=='v1'||!/^([a-f0-9]{2}){32}$/.test(value||''))continue;const sig=Uint8Array.from(value.match(/../g),v=>parseInt(v,16));if(await crypto.subtle.verify('HMAC',key,sig,new TextEncoder().encode(timestamp+'.'+raw)))return true;}
 return false;
}
export function validateCheckoutInvoice(invoice,userId){
 if(!invoice||invoice.payer_id!==userId)throw Object.assign(Error('Invoice not found'),{status:404});
 if(invoice.status!=='open')throw Object.assign(Error('This invoice is not payable'),{status:409});
 if(!Number.isSafeInteger(invoice.amount_cents)||invoice.amount_cents<50||invoice.amount_cents>1000000)throw Object.assign(Error('Invoice amount is outside supported limits'),{status:400});
}
export function safeOrigin(value){const url=new URL(value);if(url.protocol!=='https:'||url.pathname!=='/'||url.search||url.hash)throw Error('Invalid site origin');return url.origin;}
export async function limitedBody(req,limit){const reader=req.body?.getReader();if(!reader)return '';const chunks=[];let length=0;while(true){const {done,value}=await reader.read();if(done)break;length+=value.byteLength;if(length>limit){await reader.cancel();throw Object.assign(Error('Request too large'),{status:413});}chunks.push(value);}const bytes=new Uint8Array(length);let offset=0;for(const chunk of chunks){bytes.set(chunk,offset);offset+=chunk.length;}return new TextDecoder().decode(bytes);}
