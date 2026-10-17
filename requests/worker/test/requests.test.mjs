import {processEmailOutbox,emailConfigured,NOTIFY_TO} from "../src/email-outbox.js";
import { test, beforeEach, afterEach } from "node:test";
import assert from "node:assert/strict";
import { DatabaseSync } from "node:sqlite";
import { readFileSync } from "node:fs";
import app from "../src/index.js";

const ORIGIN="https://staging.worship.ipcdj.org";
const API="https://ipcdj-song-requests-staging.example.workers.dev";
const ADMIN="x".repeat(40);
const SALT="testing-isolated-salt-00000000000000000000000000001";
const schema=readFileSync(new URL("../schema.sql",import.meta.url),"utf8");
let sqlite,env,originalFetch,verificationMode,verifyCalls;
const UUIDS=[
  "c9692e06-7d2c-4d0d-bce9-2b79f2c24301",
  "c9692e06-7d2c-4d0d-bce9-2b79f2c24302",
  "c9692e06-7d2c-4d0d-bce9-2b79f2c24303",
  "c9692e06-7d2c-4d0d-bce9-2b79f2c24304",
  "c9692e06-7d2c-4d0d-bce9-2b79f2c24305",
  "c9692e06-7d2c-4d0d-bce9-2b79f2c24306",
  "c9692e06-7d2c-4d0d-bce9-2b79f2c24307",
  "c9692e06-7d2c-4d0d-bce9-2b79f2c24308"
];
function d1(db){
  const prepare=(sql,args=[])=>({
    bind:(...values)=>prepare(sql,values),
    first:async()=>db.prepare(sql).get(...args)||null,
    all:async()=>({results:db.prepare(sql).all(...args)}),
    run:async()=>db.prepare(sql).run(...args)
  });
  return {
    prepare:(sql)=>prepare(sql),
    async batch(statements){
      db.exec("BEGIN IMMEDIATE");
      try{
        const results=[];
        for(const stmt of statements)results.push(await stmt.run());
        db.exec("COMMIT");
        return results;
      }catch(e){db.exec("ROLLBACK");throw e;}
    }
  };
}
beforeEach(()=>{
  sqlite=new DatabaseSync(":memory:");
  // Node SQLite tests opt into FK enforcement; Cloudflare D1 enforces it by default.
  sqlite.exec("PRAGMA foreign_keys=ON;");
  sqlite.exec(schema);
  env={
    DB:d1(sqlite),
    APP_ENV:"staging",
    INGEST_ENABLED:"true",
    SITE_ORIGIN:ORIGIN,
    TURNSTILE_EXPECTED_HOSTNAME:"staging.worship.ipcdj.org",
    TURNSTILE_SECRET:"test-secret-not-for-production",
    IP_HASH_SALT:SALT,
    ADMIN_TOKEN:ADMIN
  };
  verifyCalls=0;verificationMode="valid";
  originalFetch=globalThis.fetch;
  globalThis.fetch=async(url,options)=>{
    assert.equal(String(url),"https://challenges.cloudflare.com/turnstile/v0/siteverify");
    assert.equal(options.method,"POST");
    verifyCalls++;
    const valid=verificationMode==="valid";
    return new Response(JSON.stringify({
      success:valid,
      hostname:verificationMode==="wrong-host"?"worship.ipcdj.org":"staging.worship.ipcdj.org",
      action:verificationMode==="wrong-action"?"login":"song_request"
    }),{status:200,headers:{"Content-Type":"application/json"}});
  };
});
afterEach(()=>{globalThis.fetch=originalFetch;sqlite.close();});
const baseBody=()=>({
  title:"Háblame de Cerca",
  artist:"Grupo Grace & Kairo Worship",
  link:"https://open.spotify.com/track/4DYvC8ozC0SF3SoyIpkuiY",
  comment:"",
  turnstileToken:"accepted-test-token",
  idempotencyKey:UUIDS[0]
});
const request=(path,method="GET",body=null,options={})=>{
  const headers=new Headers(options.headers||{});
  if(options.origin!==false)headers.set("Origin",options.origin||ORIGIN);
  if(method==="POST"){
    headers.set("Content-Type","application/json");
    if(options.ip!==false)headers.set("CF-Connecting-IP",options.ip||"203.0.113.15");
  }
  return new Request(API+path,{method,headers,body:body?JSON.stringify(body):undefined});
};
const call=async(path,method,body,options)=>{
  const response=await app.fetch(request(path,method,body,options),env);
  return {status:response.status,body:await response.json(),headers:response.headers};
};
const row=(table)=>sqlite.prepare("SELECT * FROM "+table).all();

test("foreign key constraints reject orphan submission/outbox writes",()=>{
  assert.throws(()=>sqlite.prepare(
    "INSERT INTO request_outbox(id,request_id,event_type,created_at,next_attempt_at) VALUES(?,?,?,?,?)"
  ).run("orphan-id","not-a-real-song","new_submission",new Date().toISOString(),new Date().toISOString()),/FOREIGN KEY constraint failed/);
});
test("health reports config without exposing secrets or enabling email/publication",async()=>{
  const result=await call("/health","GET");
  assert.equal(result.status,200);
  assert.equal(result.body.intakeEnabled,true);
  assert.equal(result.body.notificationsEnabled,false);
  assert.equal(result.body.publicationEnabled,false);
  assert.equal(JSON.stringify(result.body).includes(ADMIN),false);
});
test("unconfigured or disabled intake fails closed",async()=>{
  env.INGEST_ENABLED="false";
  assert.equal((await call("/v1/requests","POST",baseBody())).status,503);
  env.INGEST_ENABLED="true";
  env.TURNSTILE_SECRET="";
  assert.equal((await call("/v1/requests","POST",baseBody())).status,503);
  assert.equal(row("song_requests").length,0);
});
test("correct request persists atomically, creates one outbox event, but stays private",async()=>{
  const first=await call("/v1/requests","POST",baseBody());
  assert.equal(first.status,202);
  assert.equal(first.body.ok,true);
  assert.equal(first.body.review,"pending");
  assert.equal(first.body.replayed,false);
  assert.equal(verifyCalls,1);
  assert.equal(row("song_requests").length,1);
  assert.equal(row("request_submissions").length,1);
  assert.equal(row("request_rate_events").length,1);
  assert.equal(row("request_outbox").length,1);
  assert.equal(row("request_outbox")[0].status,"pending");
  assert.equal(row("song_requests")[0].status,"pending");
  assert.equal(row("song_requests")[0].title,"Háblame de Cerca");
  assert.equal(row("song_requests")[0].request_count,1);
  const publicFeed=await call("/v1/requests","GET");
  assert.deepEqual(publicFeed.body.songs,[]);
});
test("idempotent retries return same id with no extra verification, count or events",async()=>{
  const a=await call("/v1/requests","POST",baseBody());
  const b=await call("/v1/requests","POST",baseBody());
  assert.equal(a.status,202);assert.equal(b.status,200);
  assert.equal(a.body.requestId,b.body.requestId);
  assert.equal(b.body.replayed,true);
  assert.equal(verifyCalls,1);
  for(const table of ["song_requests","request_submissions","request_rate_events","request_outbox"]){
    assert.equal(row(table).length,1);
  }
});
test("same idempotency key cannot be reused with a different request",async()=>{
  await call("/v1/requests","POST",baseBody());
  const altered={...baseBody(),title:"Another song"};
  const next=await call("/v1/requests","POST",altered);
  assert.equal(next.status,409);
  assert.equal(next.body.error,"idempotency-conflict");
  assert.equal(row("song_requests").length,1);
});
test("accent and case variations deduplicate to one pending song with request count",async()=>{
  await call("/v1/requests","POST",baseBody());
  const second={...baseBody(),title:"HABLAME DE CERCA",artist:"GRUPO GRACE & KAIRO WORSHIP",idempotencyKey:UUIDS[1]};
  const result=await call("/v1/requests","POST",second);
  assert.equal(result.status,202);
  assert.equal(row("song_requests").length,1);
  assert.equal(row("song_requests")[0].request_count,2);
  assert.equal(row("request_submissions").length,2);
  assert.equal(row("request_outbox").length,2);
});
test("strict origin, IP presence, malformed inputs and source allowlist",async()=>{
  assert.equal((await call("/v1/requests","POST",baseBody(),{origin:"https://evil.example"})).status,403);
  assert.equal((await call("/v1/requests","POST",baseBody(),{origin:false})).status,403);
  assert.equal((await call("/v1/requests","POST",baseBody(),{ip:false})).status,403);
  assert.equal((await call("/v1/requests","POST",{...baseBody(),title:"A".repeat(130)})).status,400);
  assert.equal((await call("/v1/requests","POST",{...baseBody(),link:"https://evil.example/audio.mp3"})).status,400);
  assert.equal((await call("/v1/requests","POST",{...baseBody(),link:"javascript:alert(1)"})).status,400);
  assert.equal((await call("/v1/requests","POST",{...baseBody(),idempotencyKey:"fake-key"})).status,400);
  assert.equal(row("song_requests").length,0);
});
test("Turnstile rejects failed, wrong-host and wrong-action tokens",async()=>{
  for(const state of ["invalid","wrong-host","wrong-action"]){
    verificationMode=state;
    const response=await call("/v1/requests","POST",baseBody());
    assert.equal(response.status,403);
    assert.equal(response.body.error,"verification-failed");
  }
  assert.equal(row("song_requests").length,0);
  assert.equal(row("request_outbox").length,0);
});
test("rate limit permits 5 new requests per IP per hour, then refuses a sixth",async()=>{
  for(let i=0;i<5;i++){
    const req={...baseBody(),title:"New Title "+i,idempotencyKey:UUIDS[i]};
    assert.equal((await call("/v1/requests","POST",req)).status,202);
  }
  const next=await call("/v1/requests","POST",{...baseBody(),title:"Sixth",idempotencyKey:UUIDS[5]});
  assert.equal(next.status,429);
  assert.equal(next.body.error,"rate-limited");
  assert.equal(row("request_outbox").length,5);
});
test("admin listing and review are authenticated, auditable and do not publish",async()=>{
  const added=await call("/v1/requests","POST",baseBody());
  const id=added.body.requestId;
  assert.equal((await call("/v1/admin/requests","GET")).status,401);
  assert.equal((await call("/v1/admin/requests/"+id+"/review","POST",{action:"approve"})).status,401);
  const headers={Authorization:"Bearer "+ADMIN};
  let lst=await call("/v1/admin/requests","GET",null,{headers});
  assert.equal(lst.status,200);
  assert.equal(lst.body.requests.length,1);
  assert.equal(lst.body.requests[0].status,"pending");
  const approved=await call("/v1/admin/requests/"+id+"/review","POST",{action:"approve"},{headers});
  assert.equal(approved.status,200);assert.equal(approved.body.status,"approved");
  assert.equal(row("request_audit").length,1);
  assert.equal(row("song_requests")[0].status,"approved");
  assert.equal((await call("/v1/requests","GET")).body.songs.length,0);
  const reject=await call("/v1/admin/requests/"+id+"/review","POST",{action:"reject"},{headers});
  assert.equal(reject.body.status,"rejected");
  assert.equal(row("request_audit").length,2);
});
test("database trigger enforces rate cap even if concurrent workers missed a stale pre-read",async()=>{
  for(let i=0;i<5;i++){
    assert.equal((await call("/v1/requests","POST",{
      ...baseBody(),title:"Simultaneous-"+i,idempotencyKey:UUIDS[i]
    })).status,202);
  }
  const hash=row("request_rate_events")[0].ip_hash;
  assert.throws(()=>sqlite.prepare(
    "INSERT INTO request_rate_events(id,ip_hash,created_at) VALUES(?,?,?)"
  ).run("sixth-manual-test",hash,new Date().toISOString()),/rate-limited/);
  assert.equal(row("request_rate_events").length,5);
  assert.equal(row("song_requests").length,5);
});
test("admin audit trigger records the committed previous and new moderation states",async()=>{
  const added=await call("/v1/requests","POST",baseBody());
  const id=added.body.requestId;
  const options={headers:{Authorization:"Bearer "+ADMIN}};
  assert.equal((await call("/v1/admin/requests/"+id+"/review","POST",{action:"hold"},options)).status,200);
  assert.equal((await call("/v1/admin/requests/"+id+"/review","POST",{action:"approve"},options)).status,200);
  const audit=row("request_audit");
  assert.equal(audit.length,2);
  assert.deepEqual(audit.map(a=>[a.previous_status,a.next_status]),[
    ["pending","held"],["held","approved"]
  ]);
});
test("production environment never opens endpoints even with valid staging binding",async()=>{
  env.APP_ENV="production";
  assert.equal((await call("/v1/requests","POST",baseBody())).status,503);
  assert.equal((await call("/v1/admin/requests","GET",null,{headers:{Authorization:"Bearer "+ADMIN}})).status,503);
});

test("email delivery is fail-closed until transport, address and verified domain are configured",async()=>{
  assert.equal(NOTIFY_TO,"ipcdjofficial@gmail.com");
  assert.equal((await processEmailOutbox(env)).configured,false);
  env.EMAIL_NOTIFICATIONS_ENABLED="true";
  env.EMAIL_TO=NOTIFY_TO;
  env.EMAIL_FROM="solicitudes@ipcdj.org";
  assert.equal(emailConfigured(env),false); // no Email Service binding yet
  env.EMAIL={send:async()=>({messageId:"msg-x"})};
  assert.equal(emailConfigured(env),true);
  env.EMAIL_TO="incorrect@gmail.com";assert.equal(emailConfigured(env),false);
  env.EMAIL_TO=NOTIFY_TO;env.EMAIL_FROM="someone@gmail.com";assert.equal(emailConfigured(env),false);
  env.EMAIL_FROM="solicitudes@ipcdj.org";env.APP_ENV="production";assert.equal(emailConfigured(env),false);
  assert.equal(row("request_outbox").length,0);
});
test("pending notification is emailed to fixed inbox once then acknowledged and not resent",async()=>{
  const accepted=await call("/v1/requests","POST",baseBody());
  assert.equal(accepted.status,202);
  const sent=[];
  env.EMAIL_NOTIFICATIONS_ENABLED="true";
  env.EMAIL_TO=NOTIFY_TO;
  env.EMAIL_FROM="solicitudes@ipcdj.org";
  env.EMAIL={send:async mail=>{sent.push(mail);return {messageId:"cloudflare-accepted-01"};}};
  const stats=await processEmailOutbox(env);
  assert.deepEqual(stats,{configured:true,claimed:1,accepted:1,retried:0,failed:0});
  assert.equal(sent.length,1);
  assert.equal(sent[0].to,NOTIFY_TO);
  assert.equal(sent[0].from.email,"solicitudes@ipcdj.org");
  assert.match(sent[0].text,/Háblame de Cerca/);
  assert.equal(row("request_outbox")[0].status,"sent");
  assert.ok(row("request_outbox")[0].sent_at);
  const again=await processEmailOutbox(env);
  assert.equal(again.claimed,0);
  assert.equal(sent.length,1);
});
test("temporary Email Service failure persists a retry and does not claim delivery",async()=>{
  await call("/v1/requests","POST",baseBody());
  env.EMAIL_NOTIFICATIONS_ENABLED="true";env.EMAIL_TO=NOTIFY_TO;
  env.EMAIL_FROM="solicitudes@ipcdj.org";
  let sends=0;
  env.EMAIL={send:async()=>{sends++;if(sends===1){
    const error=new Error("do not store sensitive provider message");error.code="E_RATE_LIMIT_EXCEEDED";throw error;
  }return {messageId:"ack-on-retry"};}};
  const first=await processEmailOutbox(env);
  assert.equal(first.retried,1);
  assert.equal(row("request_outbox")[0].status,"retry");
  assert.equal(row("request_outbox")[0].last_error,"E_RATE_LIMIT_EXCEEDED");
  assert.equal(JSON.stringify(row("request_outbox")).includes("sensitive provider message"),false);
  const premature=await processEmailOutbox(env);
  assert.equal(premature.claimed,0);
  const after=await processEmailOutbox(env,{clock:()=>new Date(Date.now()+15*60*1000)});
  assert.equal(after.accepted,1);
  assert.equal(row("request_outbox")[0].status,"sent");
  assert.equal(sends,2);
});
test("missing acknowledgement retries, permanent suppressed-recipient errors terminate",async()=>{
  await call("/v1/requests","POST",baseBody());
  env.EMAIL_NOTIFICATIONS_ENABLED="true";env.EMAIL_TO=NOTIFY_TO;
  env.EMAIL_FROM="alerts@ipcdj.org";
  env.EMAIL={send:async()=>({})};
  let s=await processEmailOutbox(env);
  assert.equal(s.retried,1);
  assert.equal(row("request_outbox")[0].last_error,"E_NO_ACK");
  const error=new Error("suppressed");error.code="E_RECIPIENT_SUPPRESSED";
  env.EMAIL={send:async()=>{throw error;}};
  s=await processEmailOutbox(env,{clock:()=>new Date(Date.now()+20*60*1000)});
  assert.equal(s.failed,1);
  assert.equal(row("request_outbox")[0].status,"failed");
  assert.equal(row("request_outbox")[0].last_error,"E_RECIPIENT_SUPPRESSED");
});
test("stale sending leases are recovered; claim fences concurrent schedulers",async()=>{
  await call("/v1/requests","POST",baseBody());
  env.EMAIL_NOTIFICATIONS_ENABLED="true";env.EMAIL_TO=NOTIFY_TO;
  env.EMAIL_FROM="alerts@ipcdj.org";
  let sends=0;
  env.EMAIL={send:async()=>{sends++;return {messageId:"accepted-"+sends};}};
  const one=row("request_outbox")[0],past=new Date(Date.now()-60000).toISOString();
  sqlite.prepare("UPDATE request_outbox SET status='sending',attempts=1,next_attempt_at=? WHERE id=?")
    .run(past,one.id);
  const [a,b]=await Promise.all([processEmailOutbox(env),processEmailOutbox(env)]);
  assert.equal(a.accepted+b.accepted,1);
  assert.equal(sends,1);
  assert.equal(row("request_outbox")[0].attempts,2);
  assert.equal(row("request_outbox")[0].status,"sent");
});
test("Cron handler does not send with disabled email regardless of pending outbox",async()=>{
  await call("/v1/requests","POST",baseBody());
  let invoked=false;
  env.EMAIL={send:async()=>{invoked=true;return {messageId:"x"};}};
  env.EMAIL_TO=NOTIFY_TO;env.EMAIL_FROM="alerts@ipcdj.org";
  await app.scheduled({},env,{waitUntil:()=>{throw new Error("should not schedule");}});
  assert.equal(invoked,false);
  assert.equal(row("request_outbox")[0].status,"pending");
});

test("abandoned final attempt becomes failed after its lease expires",async()=>{
  await call("/v1/requests","POST",baseBody());
  env.EMAIL_NOTIFICATIONS_ENABLED="true";env.EMAIL_TO=NOTIFY_TO;
  env.EMAIL_FROM="alerts@ipcdj.org";
  let sends=0;
  env.EMAIL={send:async()=>{sends++;return {messageId:"unexpected"};}};
  const o=row("request_outbox")[0];
  sqlite.prepare("UPDATE request_outbox SET status='sending',attempts=8,next_attempt_at=? WHERE id=?")
    .run(new Date(Date.now()-360000).toISOString(),o.id);
  const s=await processEmailOutbox(env);
  assert.equal(s.failed,1);assert.equal(s.claimed,0);
  assert.equal(row("request_outbox")[0].status,"failed");
  assert.equal(row("request_outbox")[0].last_error,"EMAIL_ATTEMPTS_EXHAUSTED");
  assert.equal(sends,0);
});
