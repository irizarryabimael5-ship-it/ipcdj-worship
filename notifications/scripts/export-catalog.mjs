import fs from 'node:fs/promises';
import vm from 'node:vm';

const source=await fs.readFile(new URL('../../index.html',import.meta.url),'utf8');
const marker='const SONG_CATALOG_SOURCE = ';
const start=source.indexOf(marker);
if(start<0)throw new Error('SONG_CATALOG_SOURCE not found');
const arrayStart=source.indexOf('[',start+marker.length);
if(arrayStart<0)throw new Error('Catalog array start not found');

let depth=0;
let quote='';
let escaped=false;
let arrayEnd=-1;
for(let i=arrayStart;i<source.length;i++){
  const ch=source[i];
  if(quote){
    if(escaped){escaped=false;continue;}
    if(ch==='\\'){escaped=true;continue;}
    if(ch===quote)quote='';
    continue;
  }
  if(ch==='"'||ch==="'"){quote=ch;continue;}
  if(ch==='[')depth++;
  else if(ch===']'){
    depth--;
    if(depth===0){arrayEnd=i+1;break;}
  }
}
if(arrayEnd<0)throw new Error('Catalog array end not found');

const literal=source.slice(arrayStart,arrayEnd);
const catalog=vm.runInNewContext('('+literal+')',Object.create(null),{timeout:1000});
if(!Array.isArray(catalog)||!catalog.length)throw new Error('Catalog did not evaluate to a non-empty array');

const required=['id','title','activeFrom','learningStart','learningEnd','finalStart','finalEnd','releaseDayStartAt','releaseAt','releaseDayEndAt','rolloverAt','introducedAt'];
const songs=catalog.map(song=>{
  for(const key of required){
    if(!song?.[key])throw new Error('Missing '+key+' for '+(song?.id||'unknown-song'));
  }
  return {
    id:String(song.id),
    title:String(song.title),
    artist:String(song.artist||''),
    activeFrom:String(song.activeFrom),
    learningStart:String(song.learningStart),
    learningEnd:String(song.learningEnd),
    finalStart:String(song.finalStart),
    finalEnd:String(song.finalEnd),
    releaseDayStartAt:String(song.releaseDayStartAt),
    releaseAt:String(song.releaseAt),
    releaseDayEndAt:String(song.releaseDayEndAt),
    rolloverAt:String(song.rolloverAt),
    introducedAt:String(song.introducedAt)
  };
});

process.stdout.write(JSON.stringify({version:1,songs},null,2)+'\\n');
