import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';

const api=(process.env.IPCDJ_PUSH_API_ORIGIN||'https://push.worship.ipcdj.org').replace(/\\/$/,'');
const token=process.env.IPCDJ_PUSH_ADMIN_TOKEN||'';
if(!token){
  console.log('IPCDJ_PUSH_ADMIN_TOKEN is not configured; notification catalog sync skipped safely.');
  process.exit(0);
}

const exporter=fileURLToPath(new URL('./export-catalog.mjs',import.meta.url));
const payload=execFileSync(process.execPath,[exporter],{encoding:'utf8'});

const response=await fetch(api+'/v1/admin/catalog/sync',{
  method:'POST',
  headers:{
    'Content-Type':'application/json',
    'Authorization':'Bearer '+token
  },
  body:payload
});

const body=await response.text();
if(!response.ok)throw new Error('Push catalog sync failed '+response.status+': '+body);
console.log('Push catalog sync:',body);
