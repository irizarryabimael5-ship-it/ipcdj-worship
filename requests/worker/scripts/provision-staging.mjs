#!/usr/bin/env node
// IPCDJ Worship — safe Cloudflare D1 Staging-only bootstrap.
// This script NEVER deploys a Worker, enables intake, modifies Live or sends email.
import { spawnSync } from "node:child_process";
import { readFileSync, writeFileSync, copyFileSync, existsSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";

const root=resolve(dirname(fileURLToPath(import.meta.url)),"..");
const file=resolve(root,"wrangler.jsonc");
const config=JSON.parse(readFileSync(file,"utf8"));
const dbName="ipcdj-song-requests-staging";
const placeholder="00000000-0000-0000-0000-000000000000";
const pushId="e474b5be-f2a9-4c19-8756-f1adb0a5ef6a";
const uuidPattern=/^[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}$/i;
function block(message){throw new Error("STAGING BOOTSTRAP BLOCKED: "+message);}
const staging=config.env?.staging;
if(config.workers_dev!==false)block("Root Worker unexpectedly exposed");
if(Object.keys(config.env||{}).join(",")!=="staging")block("Non-staging environment present");
if(staging?.name!==dbName||staging.workers_dev!==true)block("Unexpected Staging Worker");
if(staging.vars?.APP_ENV!=="staging"||
   staging.vars?.SITE_ORIGIN!=="https://staging.worship.ipcdj.org"||
   staging.vars?.INGEST_ENABLED!=="false")block("Staging guards changed");
if(staging.d1_databases?.length!==1||
   staging.d1_databases[0].binding!=="DB"||
   staging.d1_databases[0].database_name!==dbName)block("Nonisolated D1 binding");
if(!existsSync(resolve(root,"schema.sql"))||!existsSync(resolve(root,"src/index.js")))block("Worker files missing");
if(staging.d1_databases[0].database_id===pushId)block("Refusing existing production Web Push database");
function wrangler(args,{print=true}={}){
  const r=spawnSync(process.platform==="win32"?"npx.cmd":"npx",["--no-install","wrangler",...args],{
    cwd:root,encoding:"utf8",maxBuffer:2_000_000
  });
  if(r.error||r.status!==0)block("Wrangler "+args.join(" ")+" failed. "+String(r.stderr||r.error||"").slice(0,1000));
  if(print&&r.stdout?.trim())process.stdout.write(r.stdout);
  return r.stdout.trim();
}
function dbList(){
  const output=wrangler(["d1","list","--json"],{print:false});
  let data;
  try{data=JSON.parse(output)}catch(_){block("Cannot parse D1 JSON list; refusing duplicate creation");}
  if(!Array.isArray(data))block("Unexpected D1 response structure");
  return data;
}
console.log("IPCDJ Song Requests — dedicated Staging database");
wrangler(["whoami"]);
let matches=dbList().filter(x=>x.name===dbName);
if(matches.length>1)block("Several Staging databases with identical name");
if(matches.length===0){
  console.log("Creating dedicated database "+dbName);
  wrangler(["d1","create",dbName]);
  matches=dbList().filter(x=>x.name===dbName);
  if(matches.length!==1)block("Cannot verify newly created database");
}else console.log("Existing dedicated Staging D1 found; reusing it.");
const id=matches[0].uuid;
if(typeof id!=="string"||!uuidPattern.test(id)||id===pushId||id===placeholder)block("Invalid or forbidden database ID");
if(staging.d1_databases[0].database_id!==placeholder&&staging.d1_databases[0].database_id!==id){
  block("Local Staging binding points at a different D1 database");
}
if(staging.d1_databases[0].database_id!==id){
  const backup=file+".before-staging-d1";
  if(existsSync(backup))block("Local backup already exists; inspect before retry");
  copyFileSync(file,backup);
  staging.d1_databases[0].database_id=id;
  writeFileSync(file,JSON.stringify(config,null,2)+"\n");
  console.log("Local Wrangler Staging binding updated; backup created.");
}
console.log("Applying isolated Staging SQL schema...");
wrangler(["d1","execute","DB","--env","staging","--remote","--file=./schema.sql","--yes"]);
console.log("STAGING DATABASE PROVISIONED. No Worker deployed and intake remains OFF.");
console.log("Next steps are in PROVISION_STAGING.md. Do not share secret keys.");
