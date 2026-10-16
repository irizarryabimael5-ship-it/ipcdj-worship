import { readFileSync } from 'node:fs';
import { Script } from 'node:vm';

// Every site inline script must parse. Fail early on v195-style fatal errors.
const html=readFileSync(new URL('../index.html',import.meta.url),'utf8');
const re=/<script\b([^>]*)>([\s\S]*?)<\/script>/gi;
let count=0,parsed=0,match;
while((match=re.exec(html))){
  count++;
  const attrs=match[1],body=match[2];
  if(/\bsrc\s*=/.test(attrs)||!body.trim())continue;
  const type=attrs.match(/\btype\s*=\s*["']([^"']+)["']/i)?.[1]?.toLowerCase()||'';
  if(type&&type!=='text/javascript'&&type!=='application/javascript')continue;
  try{
    new Script(body,{filename:'index.html:inline-script-'+count});
  }catch(error){
    console.error('Invalid inline script #'+count+': '+error.message);
    process.exitCode=1;
  }
  parsed++;
}
if(parsed<5){
  console.error('Unexpectedly few executable site scripts: '+parsed);
  process.exitCode=1;
}
if(!process.exitCode)console.log('Valid syntax for '+parsed+' executable inline scripts.');
