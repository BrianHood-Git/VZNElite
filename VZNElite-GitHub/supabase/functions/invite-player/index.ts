import { createClient } from "npm:@supabase/supabase-js@2.118.0";
const allowed=new Set(["https://vznelite.org","https://vzn-elite.vzn-elite.workers.dev","https://vzn-elite.hrianbood.workers.dev","http://127.0.0.1:5173"]);
Deno.serve(async req=>{
 const origin=req.headers.get("origin")||"";
 const headers={"Access-Control-Allow-Origin":allowed.has(origin)?origin:"https://vznelite.org","Access-Control-Allow-Headers":"authorization,apikey,content-type,x-client-info","Access-Control-Allow-Methods":"POST,OPTIONS","Content-Type":"application/json","Vary":"Origin"};
 const reply=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers});
 if(origin&&!allowed.has(origin))return reply({error:"Origin is not allowed"},403);
 if(req.method==="OPTIONS")return new Response(null,{headers});
 if(req.method!=="POST")return reply({error:"POST required"},405);
 try{
 const auth=req.headers.get("Authorization");if(!auth?.startsWith("Bearer "))return reply({error:"Sign in first"},401);
 const url=Deno.env.get("SUPABASE_URL")!,key=Deno.env.get("SUPABASE_ANON_KEY")!;
 const userClient=createClient(url,key,{global:{headers:{Authorization:auth}},auth:{persistSession:false,autoRefreshToken:false}});
 const {data:{user},error}=await userClient.auth.getUser(auth.slice(7));if(error||!user)return reply({error:"Session is invalid; sign in again"},401);
 const body=await req.json();if(typeof body.player_id!=="string"||typeof body.email!=="string")return reply({error:"Player and email required"},400);
 const email=body.email.trim().toLowerCase();
 const invitation=await userClient.rpc("create_player_invitation",{p:body.player_id,target_email:email});
 if(invitation.error)return reply({error:invitation.error.message},403);
 const mailClient=createClient(url,key,{auth:{persistSession:false,autoRefreshToken:false}});
 const mail=await mailClient.auth.signInWithOtp({email,options:{emailRedirectTo:"https://vznelite.org/"}});
 return reply({invitation_id:invitation.data,sent:!mail.error,email_error:mail.error?"The email service did not accept delivery. Verify custom SMTP and email rate limits.":null});
 }catch{return reply({error:"Unable to process invitation"},400);}
});
