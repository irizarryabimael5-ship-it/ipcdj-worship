import test from 'node:test';
import assert from 'node:assert/strict';
import { buildSongNotificationPlan, renderMessage, templateKinds } from '../core/planner.mjs';

const song={
  id:'glorioso-dia', title:'Glorioso Día', artist:'Passion Music',
  activeFrom:'2026-09-28T06:00:00-04:00',
  learningStart:'2026-10-12T00:00:00-04:00',
  learningEnd:'2026-10-18T23:59:59-04:00',
  finalStart:'2026-10-19T00:00:00-04:00',
  finalEnd:'2026-10-24T23:59:59-04:00',
  releaseDayStartAt:'2026-10-25T00:00:00-04:00',
  releaseAt:'2026-10-25T11:00:00-04:00',
  releaseDayEndAt:'2026-10-26T00:00:00-04:00',
  rolloverAt:'2026-10-26T06:00:00-04:00',
  introducedAt:'2026-10-27T00:00:00-04:00'
};

test('planner produces an intentional bounded sequence',()=>{
  const plan=buildSongNotificationPlan(song,{
    nowMs:Date.parse('2026-09-21T15:00:00-04:00'),
    firstSeenAtMs:Date.parse('2026-09-21T15:00:00-04:00')
  });
  assert.equal(plan.length,6);
  assert.deepEqual(plan.map(x=>x.kind),['added','learning_start','learning_mid','final_start','release_eve','release_day']);
  assert.equal(new Set(plan.map(x=>x.eventKey)).size,plan.length);
});

test('planned delivery times avoid overnight hours in New York',()=>{
  const plan=buildSongNotificationPlan(song,{nowMs:Date.parse('2026-09-21T15:00:00-04:00')});
  for(const event of plan){
    const hour=Number(new Intl.DateTimeFormat('en-US',{
      timeZone:'America/New_York',hour:'2-digit',hourCycle:'h23'
    }).format(new Date(event.scheduledAt)));
    assert.ok(hour>=8&&hour<21,event.kind+' scheduled at quiet hour '+hour);
  }
});

test('messages stay short, song-aware and deterministic on retry',()=>{
  for(const kind of templateKinds()){
    const key='auto:'+song.id+':'+kind+':example';
    const first=renderMessage(kind,song,key);
    const retry=renderMessage(kind,song,key);
    assert.deepEqual(first,retry);
    assert.ok(first.title.length<=70,kind+' title too long');
    assert.ok(first.body.length<=150,kind+' body too long');
  }
});


test('late activation never replays stale reminders or claims a song was just added',()=>{
  const plan=buildSongNotificationPlan(song,{
    nowMs:Date.parse('2026-10-20T14:00:00-04:00'),
    firstSeenAtMs:Date.parse('2026-10-20T14:00:00-04:00')
  });
  assert.deepEqual(plan.map(x=>x.kind),['release_eve','release_day']);
  assert.equal(plan.some(x=>x.kind==='added'),false);
  assert.equal(plan.some(x=>['learning_start','learning_mid','final_start'].includes(x.kind)),false);
});

test('a future song still receives the complete intentional sequence',()=>{
  const plan=buildSongNotificationPlan(song,{
    nowMs:Date.parse('2026-09-21T15:00:00-04:00'),
    firstSeenAtMs:Date.parse('2026-09-21T15:00:00-04:00')
  });
  assert.deepEqual(plan.map(x=>x.kind),['added','learning_start','learning_mid','final_start','release_eve','release_day']);
});

test('DST-crossing lifecycle remains scheduled in New York local time',()=>{
  const dstSong={
    id:'no-fallaras', title:'No Fallarás', artist:'Saddleback Worship',
    activeFrom:'2026-10-26T06:00:00-04:00',
    learningStart:'2026-10-26T00:00:00-04:00',
    learningEnd:'2026-11-01T23:59:59-05:00',
    finalStart:'2026-11-02T00:00:00-05:00',
    finalEnd:'2026-11-07T23:59:59-05:00',
    releaseDayStartAt:'2026-11-08T00:00:00-05:00',
    releaseAt:'2026-11-08T11:00:00-05:00',
    releaseDayEndAt:'2026-11-09T00:00:00-05:00',
    rolloverAt:'2026-11-09T06:00:00-05:00',
    introducedAt:'2026-11-10T00:00:00-05:00'
  };
  const plan=buildSongNotificationPlan(dstSong,{
    nowMs:Date.parse('2026-10-25T15:00:00-04:00'),
    firstSeenAtMs:Date.parse('2026-10-25T15:00:00-04:00')
  });
  const byKind=Object.fromEntries(plan.map(event=>[event.kind,event]));
  const localHour=iso=>Number(new Intl.DateTimeFormat('en-US',{
    timeZone:'America/New_York',hour:'2-digit',hourCycle:'h23'
  }).format(new Date(iso)));
  assert.equal(localHour(byKind.learning_start.scheduledAt),9);
  assert.equal(localHour(byKind.final_start.scheduledAt),9);
  assert.equal(localHour(byKind.release_eve.scheduledAt),18);
  assert.equal(localHour(byKind.release_day.scheduledAt),8);
});


test('wording engine composes more than the six original fixed pairs',()=>{
  const variants=new Set();
  for(let i=0;i<80;i++){
    const msg=renderMessage('learning_start',song,'auto:'+song.id+':learning_start:sample-'+i);
    variants.add(msg.title+'|'+msg.body);
  }
  assert.ok(variants.size>6,'expected independently varied title/body combinations');
});

test('final preparation wording always includes the estreno date context',()=>{
  for(let i=0;i<30;i++){
    const msg=renderMessage('final_start',song,'auto:'+song.id+':final_start:sample-'+i);
    assert.match(msg.body,/octubre/i);
  }
});
