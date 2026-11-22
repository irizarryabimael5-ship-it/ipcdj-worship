import {test,expect} from '@playwright/test';

// Owner-directed, STAGING-ONLY December 2026 – May 2027 release calendar, including EDT handoff.
// These assertions intentionally fail if any former estreno date leaks back.
const schedule=[
  {id:'con-manos-vacias',title:'Con Manos Vacías',artist:'Jesús Adrián Romero',
    active:'2026-09-28T06:00:00-04:00',learning:'2026-11-02T00:00:00-05:00',
    lastLearning:'2026-11-08T23:59:59-05:00',final:'2026-11-09T00:00:00-05:00',
    lastFinal:'2026-12-26T23:59:59-05:00',release:'2026-12-27T11:00:00-05:00',
    rollover:'2026-12-28T06:00:00-05:00',provider:'itunes'},
  {id:'glorioso-dia',title:'Glorioso Día',artist:'Passion Music',
    active:'2026-12-28T06:00:00-05:00',learning:'2027-01-04T00:00:00-05:00',
    lastLearning:'2027-01-10T23:59:59-05:00',final:'2027-01-11T00:00:00-05:00',
    lastFinal:'2027-01-16T23:59:59-05:00',release:'2027-01-17T11:00:00-05:00',
    rollover:'2027-01-18T06:00:00-05:00',provider:'spotify'},
  {id:'no-fallaras',title:'No Fallarás',artist:'Saddleback Worship',
    active:'2027-01-18T06:00:00-05:00',learning:'2027-02-01T00:00:00-05:00',
    lastLearning:'2027-02-07T23:59:59-05:00',final:'2027-02-08T00:00:00-05:00',
    lastFinal:'2027-02-13T23:59:59-05:00',release:'2027-02-14T11:00:00-05:00',
    rollover:'2027-02-15T06:00:00-05:00',provider:'spotify'},
  {id:'reinas-por-la-eternidad',title:'Reinas Por La Eternidad',artist:'Hillsong en Español',
    active:'2027-02-15T06:00:00-05:00',learning:'2027-02-22T00:00:00-05:00',
    lastLearning:'2027-02-28T23:59:59-05:00',final:'2027-03-01T00:00:00-05:00',
    lastFinal:'2027-03-06T23:59:59-05:00',release:'2027-03-07T11:00:00-05:00',
    rollover:'2027-03-08T06:00:00-05:00',provider:'itunes'},
  {id:'ante-ti-jc-negron',title:'Ante Ti',artist:'JC Negron',
    active:'2027-03-08T06:00:00-05:00',learning:'2027-03-15T00:00:00-04:00',
    lastLearning:'2027-03-21T23:59:59-04:00',final:'2027-03-22T00:00:00-04:00',
    lastFinal:'2027-03-27T23:59:59-04:00',release:'2027-03-28T11:00:00-04:00',
    rollover:'2027-03-29T06:00:00-04:00',provider:'itunes'},
  {id:'encontre-generacion-12',title:'Encontré',artist:'Generación 12',
    active:'2027-03-29T06:00:00-04:00',learning:'2027-04-05T00:00:00-04:00',
    lastLearning:'2027-04-11T23:59:59-04:00',final:'2027-04-12T00:00:00-04:00',
    lastFinal:'2027-04-17T23:59:59-04:00',release:'2027-04-18T11:00:00-04:00',
    rollover:'2027-04-19T06:00:00-04:00',provider:'itunes'},
  {id:'mi-gozo-live-barak',title:'Mi Gozo (Live)',artist:'Barak',
    active:'2027-04-19T06:00:00-04:00',learning:'2027-04-26T00:00:00-04:00',
    lastLearning:'2027-05-02T23:59:59-04:00',final:'2027-05-03T00:00:00-04:00',
    lastFinal:'2027-05-08T23:59:59-04:00',release:'2027-05-09T11:00:00-04:00',
    rollover:'2027-05-10T06:00:00-04:00',provider:'itunes'},
  {id:'asi-sera-it-is-so-elevation-ep',title:'Así Será (It Is So)',artist:'Elevation Worship & Elevation Español',
    active:'2027-05-10T06:00:00-04:00',learning:'2027-05-17T00:00:00-04:00',
    lastLearning:'2027-05-23T23:59:59-04:00',final:'2027-05-24T00:00:00-04:00',
    lastFinal:'2027-05-29T23:59:59-04:00',release:'2027-05-30T11:00:00-04:00',
    rollover:'2027-05-31T06:00:00-04:00',provider:'itunes'}
];
test.beforeEach(async({page})=>{
  await page.clock.setFixedTime(new Date('2026-10-24T19:00:00-04:00'));
  await page.goto('/',{waitUntil:'domcontentloaded'});
  await page.waitForFunction(()=>!!window.IPCDJ_CATALOG&&!!window.IPCDJ_CATALOG_TEST);
});
test('full eight-song date, media and branch-isolation contract',async({page,request})=>{
  const audit=await page.evaluate(()=>{
    const api=window.IPCDJ_CATALOG;
    return {health:api.health,songs:api.songs,tbd:api.tbd,
      snapshot:api.snapshot(Date.parse('2026-10-24T19:00:00-04:00')),
      staging:document.querySelector('meta[name="ipcdj-environment"]')?.content
    };
  });
  expect(audit.staging).toBe('staging');
  expect(audit.health.valid).toBe(true);
  expect(audit.health.fullVisualReady).toBe(true);
  expect(audit.tbd).toEqual([]);
  const upcoming=audit.songs.filter(x=>schedule.some(s=>s.id===x.id));
  expect(upcoming).toHaveLength(8);
  expect(upcoming.map(x=>x.id)).toEqual(schedule.map(x=>x.id));
  expect(schedule[0].learning).toBe('2026-11-02T00:00:00-05:00');
  expect(schedule[0].lastLearning).toBe('2026-11-08T23:59:59-05:00');
  expect(schedule[0].final).toBe('2026-11-09T00:00:00-05:00');
  expect(schedule[0].lastFinal).toBe('2026-12-26T23:59:59-05:00');
  // The first release moved one more day to Sunday; verify all seven intervals.
  const days=schedule.map(s=>Date.parse(s.release.slice(0,10)+'T00:00:00Z'));
  expect(days.slice(1).map((d,i)=>(d-days[i])/86400000)).toEqual([21,28,21,21,21,21,21]);
  for(let i=1;i<schedule.length;i++){
    expect(schedule[i].active).toBe(schedule[i-1].rollover);
    expect(Date.parse(schedule[i].learning)-Date.parse(schedule[i-1].release)).toBeGreaterThanOrEqual(7*24*60*60*1000);
  }
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
  const ante=upcoming.find(x=>x.id==='ante-ti-jc-negron');
  const encontre=upcoming.find(x=>x.id==='encontre-generacion-12');
  expect(Date.parse(encontre.releaseAt)-Date.parse(ante.releaseAt)).toBe(21*24*60*60*1000);
  expect(encontre.activeFrom).toBe(ante.rolloverAt);
  expect(encontre.itunesTrackId).toBe('1838982752');
  expect(encontre.itunesCollectionId).toBe('1838982743');
  expect(encontre.artworkSource).toBe('generacion12-encontre-2022-single-artwork-reference');
  expect(encontre.futurePalette).toEqual([[166,102,94],[202,133,120],[41,35,36]]);
  const miGozo=upcoming.find(x=>x.id==='mi-gozo-live-barak');
  // After the DST change, Ante Ti Mar 28 to Encontré Apr 18 spans exactly 21 calendar days and 21x24 hours.
  const zonedDate=(iso)=>new Intl.DateTimeFormat('en-CA',{
    timeZone:'America/New_York',year:'numeric',month:'2-digit',day:'2-digit'
  }).format(new Date(iso));
  expect(zonedDate(miGozo.releaseAt)).toBe('2027-05-09');
  expect(zonedDate(encontre.releaseAt)).toBe('2027-04-18');
  expect(Date.parse(miGozo.releaseAt)-Date.parse(encontre.releaseAt)).toBe(21*24*60*60*1000);
  expect(miGozo.activeFrom).toBe(encontre.rolloverAt);
  expect(miGozo.itunesTrackId).toBe('1783806482');
  expect(miGozo.itunesCollectionId).toBe('1783806472');
  expect(miGozo.album).toBe('Fuego & Poder (Live)');
  expect(miGozo.artworkUrl).toBe('https://i.scdn.co/image/ab67616d0000b2730a45cc0e99318eda67b32111');
  expect(miGozo.futurePalette).toEqual([[45,62,80],[137,95,97],[82,110,132]]);
  const asiSera=upcoming.find(x=>x.id==='asi-sera-it-is-so-elevation-ep');
  expect(asiSera.activeFrom).toBe(miGozo.rolloverAt);
  expect(Date.parse(asiSera.releaseAt)-Date.parse(miGozo.releaseAt)).toBe(21*24*60*60*1000);
  expect(asiSera.title).toBe('Así Será (It Is So)');
  expect(asiSera.artist).toBe('Elevation Worship & Elevation Español');
  expect(asiSera.album).toBe('A La Medianoche - EP');
  expect(asiSera.itunesCollectionId).toBe('1494360193');
  expect(asiSera.itunesTrackId).toBe('1494360203');
  expect(asiSera.artworkUrl).toBe('https://i.scdn.co/image/ab67616d0000b273eb0c5a6a1f6931c64055a63e');
  expect(asiSera.artworkSource).toBe('spotify-elevation-worship-a-la-medianoche-ep-2020');
  expect(asiSera.futurePalette).toEqual([[19,69,94],[68,163,207],[212,232,53]]);
  expect(audit.snapshot.current).toContain('con-manos-vacias');
  expect(audit.snapshot.upcoming).toEqual(['glorioso-dia','no-fallaras','reinas-por-la-eternidad','ante-ti-jc-negron','encontre-generacion-12','mi-gozo-live-barak','asi-sera-it-is-so-elevation-ep']);
  await expect(page.locator('#upcoming-songs [data-song-id]')).toHaveCount(7);
  await expect(page.locator('#current-song-cards [data-song-id="con-manos-vacias"]')).toHaveCount(1);
  await expect(page.locator('#requested-songs [data-request-song-id]')).toHaveCount(6);
  await expect(page.locator('#upcoming-songs [data-request-song-id]')).toHaveCount(0);
  const html=await (await request.get('/?new-estrenos='+Date.now(),{headers:{'cache-control':'no-cache'}})).text();
  expect(html).toContain('const SONG_TBD_SOURCE=Object.freeze([])');
  expect(html).toContain('itunesTrackId:"1603316057"');
  expect(html).toContain('itunesTrackId:"1785402419"');
  expect(html).toContain('itunesTrackId:"1150302554"');
  expect(html).toContain('itunesTrackId:"1838982752"');
  expect(html).toContain('releaseAt:"2027-04-18T11:00:00-04:00"');
  expect(html).toContain('itunesTrackId:"1783806482"');
  expect(html).toContain('releaseAt:"2027-05-09T11:00:00-04:00"');
  expect(html).toContain('itunesTrackId:"1494360203"');
  expect(html).toContain('releaseAt:"2027-05-30T11:00:00-04:00"');
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
  expect(song.releaseAt).toBe('2026-12-27T11:00:00-05:00');
  expect(song.hasPreview).toBe(true);
});

test('Dec 27 final preparation and live countdown/progress stay synchronized',async({page})=>{
 const check=await page.evaluate(()=>{
  try{return ['2026-11-14T12:00:00-05:00','2026-12-26T23:59:59-05:00','2026-12-27T00:00:00-05:00','2026-12-27T11:00:00-05:00','2026-12-27T11:30:00-05:00','2026-12-28T06:00:00-05:00'].map(at=>{
   const now=Date.parse(at);window.IPCDJ_CATALOG_TEST.renderAt(now);
   const el=document.querySelector('[data-current-song-card][data-song-id="con-manos-vacias"]');
   return {phase:window.IPCDJ_CATALOG.phase('con-manos-vacias',now).key,
    pct:el?parseFloat(el.querySelector('[data-role="progress-fill"]')?.style.width||'NaN'):null,
    aria:el?Number(el.querySelector('[data-role="progress-track"]')?.getAttribute('aria-valuenow')):null,
    target:el?.querySelector('[data-role="countdown-target"]')?.textContent?.trim()||'',
    next:!!document.querySelector('[data-current-song-card][data-song-id="glorioso-dia"]')};
  })}finally{window.IPCDJ_CATALOG_TEST.resume()}
 });
 expect(check.map(x=>x.phase)).toEqual(['final','final','release','release','released','complete']);
 expect(check[0].pct).toBeGreaterThan(0);
 expect(check[0].pct).toBeLessThan(check[1].pct);
 expect(check[1].pct).toBeLessThan(100);
 expect(check[0].target).toContain('27 Dic');
 expect(check[3].pct).toBe(100);
 expect(check[3].aria).toBe(100);
 expect(check[5].next).toBe(true);
});

test('Nov 21 current preparation survives postponement with synced countdown and progress',async({page})=>{
  const state=await page.evaluate(()=>{
    const now=Date.parse('2026-11-21T12:00:00-05:00');
    const song=window.IPCDJ_CATALOG.songs.find(x=>x.id==='con-manos-vacias');
    try{
      window.IPCDJ_CATALOG_TEST.renderAt(now);
      const card=document.querySelector('[data-current-song-card][data-song-id="con-manos-vacias"]');
      return {
        phase:window.IPCDJ_CATALOG.phase('con-manos-vacias',now).key,
        title:card?.querySelector('[data-role="status"]')?.textContent?.trim(),
        target:card?.querySelector('[data-role="countdown-target"]')?.textContent?.trim(),
        percentage:parseFloat(card?.querySelector('[data-role="progress-fill"]')?.style.width||'NaN'),
        aria:Number(card?.querySelector('[data-role="progress-track"]')?.getAttribute('aria-valuenow')),
        expected:100*(now-Date.parse(song.learningStart))/
          (Date.parse(song.releaseAt)-Date.parse(song.learningStart)),
        days:Number(card?.querySelector('[data-role="countdown-days"]')?.textContent||'NaN')
      };
    }finally{window.IPCDJ_CATALOG_TEST.resume();}
  });
  expect(state.phase).toBe('final');
  expect(state.title).toBe('AHORA EN PREPARACIÓN');
  expect(state.target).toContain('27 Dic');
  expect(state.percentage).toBeGreaterThan(30);
  expect(state.percentage).toBeLessThan(40);
  expect(Math.abs(state.percentage-state.expected)).toBeLessThan(.001);
  expect(state.aria).toBe(Math.round(state.expected));
  expect(state.days).toBeGreaterThan(30);
});
