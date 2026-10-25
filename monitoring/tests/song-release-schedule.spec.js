import {test,expect} from '@playwright/test';

// Owner-approved LIVE November 2026 – January 2027 song calendar.
// These assertions intentionally fail if any former estreno date leaks back.
const schedule=[
  {id:'con-manos-vacias',title:'Con Manos Vacías',artist:'Jesús Adrián Romero',
    active:'2026-09-28T06:00:00-04:00',learning:'2026-11-02T00:00:00-05:00',
    lastLearning:'2026-11-08T23:59:59-05:00',final:'2026-11-09T00:00:00-05:00',
    lastFinal:'2026-11-14T23:59:59-05:00',release:'2026-11-15T11:00:00-05:00',
    rollover:'2026-11-16T06:00:00-05:00',provider:'itunes'},
  {id:'glorioso-dia',title:'Glorioso Día',artist:'Passion Music',
    active:'2026-11-16T06:00:00-05:00',learning:'2026-11-23T00:00:00-05:00',
    lastLearning:'2026-11-29T23:59:59-05:00',final:'2026-11-30T00:00:00-05:00',
    lastFinal:'2026-12-05T23:59:59-05:00',release:'2026-12-06T11:00:00-05:00',
    rollover:'2026-12-07T06:00:00-05:00',provider:'spotify'},
  {id:'no-fallaras',title:'No Fallarás',artist:'Saddleback Worship',
    active:'2026-12-07T06:00:00-05:00',learning:'2026-12-21T00:00:00-05:00',
    lastLearning:'2026-12-27T23:59:59-05:00',final:'2026-12-28T00:00:00-05:00',
    lastFinal:'2027-01-02T23:59:59-05:00',release:'2027-01-03T11:00:00-05:00',
    rollover:'2027-01-04T06:00:00-05:00',provider:'spotify'},
  {id:'reinas-por-la-eternidad',title:'Reinas Por La Eternidad',artist:'Hillsong en Español',
    active:'2027-01-04T06:00:00-05:00',learning:'2027-01-11T00:00:00-05:00',
    lastLearning:'2027-01-17T23:59:59-05:00',final:'2027-01-18T00:00:00-05:00',
    lastFinal:'2027-01-23T23:59:59-05:00',release:'2027-01-24T11:00:00-05:00',
    rollover:'2027-01-25T06:00:00-05:00',provider:'itunes'}
];
test.beforeEach(async({page})=>{
  await page.clock.setFixedTime(new Date('2026-10-24T19:00:00-04:00'));
  await page.goto('/',{waitUntil:'domcontentloaded'});
  await page.waitForFunction(()=>!!window.IPCDJ_CATALOG&&!!window.IPCDJ_CATALOG_TEST);
});
test('full four-song date, media and branch-isolation contract',async({page,request})=>{
  const audit=await page.evaluate(()=>{
    const api=window.IPCDJ_CATALOG;
    return {health:api.health,songs:api.songs,tbd:api.tbd,
      snapshot:api.snapshot(Date.parse('2026-10-24T19:00:00-04:00')),
      staging:document.querySelector('meta[name="ipcdj-environment"]')?.content
    };
  });
  expect(audit.staging).toBeUndefined();
  expect(audit.health.valid).toBe(true);
  expect(audit.health.fullVisualReady).toBe(true);
  expect(audit.tbd).toEqual([]);
  const upcoming=audit.songs.filter(x=>schedule.some(s=>s.id===x.id));
  expect(upcoming).toHaveLength(4);
  expect(upcoming.map(x=>x.id)).toEqual(schedule.map(x=>x.id));
  for(const expected of schedule){
    const song=upcoming.find(x=>x.id===expected.id);
    expect(song.title).toBe(expected.title);
    expect(song.artist).toBe(expected.artist);
    expect(song.activeFrom).toBe(expected.active);
    expect(song.learningStart).toBe(expected.learning);
    expect(song.learningEnd).toBe(expected.lastLearning);
    expect(song.finalStart).toBe(expected.final);
    expect(song.finalEnd).toBe(expected.lastFinal);
    expect(song.releaseAt).toBe(expected.release);
    expect(song.rolloverAt).toBe(expected.rollover);
    expect(song.introducedAt).toBe(expected.rollover);
    expect(song.hasPreview).toBe(true);
    expect(song.artworkUrl).toMatch(/^https:\/\//);
    if(expected.id==='con-manos-vacias'){
      expect(song.artworkUrl).toBe('https://i.scdn.co/image/ab67616d0000b273318e79e589ae23303377e69e');
      expect(song.artworkSource).toBe('spotify-coleccion-adoracion');
      expect(song.futurePalette).toEqual([[33,96,162],[109,176,223],[24,59,110]]);
    }
    expect(song.futurePalette).toHaveLength(3);
    expect(song.fullVisualReady).toBe(true);
    expect(Date.parse(song.learningStart)).toBeGreaterThan(Date.parse(song.activeFrom));
    expect(Date.parse(song.learningStart)).toBeLessThan(Date.parse(song.finalStart));
    expect(Date.parse(song.finalStart)).toBeLessThan(Date.parse(song.releaseAt));
    const day=await page.evaluate(timestamp=>new Intl.DateTimeFormat('en-US',{
      timeZone:'America/New_York',weekday:'long'
    }).format(new Date(timestamp)),expected.release);
    expect(day).toBe('Sunday');
  }
  expect(audit.snapshot.current).toContain('con-manos-vacias');
  expect(audit.snapshot.upcoming).toEqual(['glorioso-dia','no-fallaras','reinas-por-la-eternidad']);
  await expect(page.locator('#upcoming-songs [data-song-id]')).toHaveCount(3);
  await expect(page.locator('#current-song-cards [data-song-id="con-manos-vacias"]')).toHaveCount(1);
  await expect(page.locator('#upcoming-songs [data-request-song-id]')).toHaveCount(0);
  const html=await (await request.get('/?new-estrenos='+Date.now(),{headers:{'cache-control':'no-cache'}})).text();
  expect(html).toContain('const SONG_TBD_SOURCE=Object.freeze([])');
  expect(html).toContain('itunesTrackId:"1603316057"');
  expect(html).toContain('itunesTrackId:"1785402419"');
});
test('each premiere transitions into next current song and finally into history',async({page})=>{
  const state=await page.evaluate(schedule=>{
    const api=window.IPCDJ_CATALOG;
    return schedule.map((song,index)=>{
      const before=api.snapshot(Date.parse(song.rollover)-1000);
      const after=api.snapshot(Date.parse(song.rollover));
      const learn=api.phase(song.id,Date.parse(song.learning));
      const final=api.phase(song.id,Date.parse(song.final));
      const release=api.phase(song.id,Date.parse(song.release));
      return {id:song.id,before,after,learn:learn.key,final:final.key,release:release.key,next:schedule[index+1]?.id||null};
    });
  },schedule);
  for(const row of state){
    expect(row.before.current).toContain(row.id);
    expect(row.before.introduced).not.toContain(row.id);
    expect(row.after.current).not.toContain(row.id);
    expect(row.after.introduced).toContain(row.id);
    expect(row.learn).toBe('learning');
    expect(row.final).toBe('final');
    expect(row.release).toBe('release');
    if(row.next)expect(row.after.current).toContain(row.next);
  }
});
test('new Jesús Adrián Romero card has its verified Apple media identity and playable preview',async({page})=>{
  const row=page.locator('#current-song-cards [data-preview-song-id="con-manos-vacias"]');
  const button=row.locator('.preview-button');
  await expect(button).toBeVisible();
  await expect(button).toBeEnabled();
  await page.waitForFunction(()=>{
    const launch=document.getElementById('ipcdj-launch');
    return !launch||launch.classList.contains('launch-idle')||
      !document.documentElement.classList.contains('ipcdj-launch-active');
  },null,{timeout:30000});
  await button.click();
  await expect.poll(()=>row.evaluate(node=>node.classList.contains('is-playing')),
    {timeout:25000,message:'Exact Apple preview should play for Con Manos Vacías'}).toBe(true);
  const audio=await row.evaluate(node=>({
    provider:node._previewData?.previewProvider,
    title:node._previewData?.trackName,
    artist:node._previewData?.artistName,
    url:node._previewData?.previewUrl
  }));
  expect(audio.provider).toBe('itunes');
  expect(audio.title?.toLowerCase()).toContain('con manos vacías');
  expect(audio.artist?.toLowerCase()).toContain('jesús');
  expect(audio.url).toMatch(/^https:\/\//);
  await button.click();
  await expect(row).not.toHaveClass(/is-playing/);
});

test('Colección Adoración artwork wins over a stale saved cover and theme',async({page})=>{
  const art='https://i.scdn.co/image/ab67616d0000b273318e79e589ae23303377e69e';
  // Simulate a browser which visited the former original-album version.
  await page.evaluate(()=>{
    localStorage.setItem('ipcdj-cover-boot-v1',JSON.stringify([{
      songId:'con-manos-vacias',
      url:'https://i.scdn.co/image/ab67616d0000b273fa9615e633aae10e815be801',
      savedAt:Date.now()
    }]));
    localStorage.setItem('ipcdj-cover-theme-v2:con-manos-vacias',JSON.stringify([
      [250,4,4],[250,4,4],[250,4,4]
    ]));
  });
  await page.reload({waitUntil:'domcontentloaded'});
  await page.waitForFunction(()=>!!window.IPCDJ_CATALOG);
  const card=page.locator('#current-song-cards [data-current-song-card][data-song-id="con-manos-vacias"]');
  await expect(card).toHaveCount(1);
  await expect(card).toHaveAttribute('data-cover-artwork-url',art);
  await expect(card).toHaveAttribute('data-cover-artwork-source','verified-spotify-coleccion-adoracion');
  await expect(card.locator('.cover-native-fallback')).toHaveAttribute('src',art);
  const theme=await card.evaluate(node=>getComputedStyle(node).getPropertyValue('--cover-c1').trim());
  expect(theme).not.toBe('250,4,4');
  const song=await page.evaluate(()=>window.IPCDJ_CATALOG.songs.find(x=>x.id==='con-manos-vacias'));
  expect(song.releaseAt).toBe('2026-11-15T11:00:00-05:00');
  expect(song.hasPreview).toBe(true);
});
