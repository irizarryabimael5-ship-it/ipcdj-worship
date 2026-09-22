const siteOrigin='https://worship.ipcdj.org';
const api=(process.env.IPCDJ_PUSH_API_ORIGIN||'https://push.worship.ipcdj.org').replace(/\/$/,'');
const headers={Origin:siteOrigin,'Cache-Control':'no-cache'};

async function read(path){
  const response=await fetch(api+path,{headers,cache:'no-store'});
  const text=await response.text();
  let data={};
  try{ data=JSON.parse(text); }catch(_){}
  if(!response.ok)throw new Error(path+' returned '+response.status+': '+text.slice(0,300));
  return {response,data};
}

const health=await read('/health');
if(health.data?.ok!==true)throw new Error('Backend health did not report ok');
if(health.data?.configured!==true)throw new Error('Backend health reports configured=false');

const config=await read('/v1/config');
if(config.data?.enabled!==true)throw new Error('Remote push config is not enabled');
if(!config.data?.vapidPublicKey)throw new Error('Remote VAPID public key is missing');
if(config.data?.timezone!=='America/New_York')throw new Error('Unexpected notification timezone');

const allowOrigin=config.response.headers.get('access-control-allow-origin');
if(allowOrigin!==siteOrigin)throw new Error('Remote CORS does not allow IPCDJ Worship origin');

console.log(JSON.stringify({
  ok:true,
  api,
  service:health.data.service,
  timezone:config.data.timezone,
  cors:allowOrigin
},null,2));
