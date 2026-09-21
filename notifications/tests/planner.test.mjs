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
