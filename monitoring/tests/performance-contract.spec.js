import {test,expect} from '@playwright/test';

// #41: Keep the exact same DOM, colors, CSS animation, countdown and controls,
// but avoid writing unchanged style/ARIA attributes once every second.
test.beforeEach(async ({page},testInfo)=>{
  test.skip(!['chromium-desktop','webkit-tablet'].includes(testInfo.project.name),
    'Measure deterministic render churn on desktop Chromium and iPad-sized WebKit; site-health covers the full seven-profile matrix.');
  await page.clock.setFixedTime(new Date('2026-11-15T09:00:00-05:00'));
  await page.goto('/',{waitUntil:'domcontentloaded'});
  await page.waitForFunction(()=>!!window.IPCDJ_CATALOG_TEST&&!!window.IPCDJ_CATALOG);
});

test('repeated same-second current-card renders avoid redundant DOM and style mutations',async({page})=>{
  const audit=await page.evaluate(()=>{
    const clock=window.IPCDJ_CATALOG_TEST;
    const now=Date.parse('2026-11-16T12:00:00-05:00');
    try{
      clock.renderAt(now);
      const card=document.querySelector('#current-song-cards [data-current-song-card]');
      if(!card)throw Error('Current song missing');
      const select=role=>card.querySelector('[data-role="'+role+'"]');
      const progress=()=>Number.parseFloat(select('progress-fill')?.style.width||'NaN');
      const countdown=()=>[
        'countdown-days','countdown-hours','countdown-minutes','countdown-seconds'
      ].map(x=>Number(select(x)?.textContent||0));
      const baseline={
        phase:card.dataset.phase,
        progress:progress(),
        countdown:countdown(),
        phaseLabel:select('progress-phase')?.textContent,
        aria:select('progress-track')?.getAttribute('aria-valuenow'),
        colors:['--stage-accent','--stage-soft','--stage-border','--stage-glow','--stage-text']
          .map(v=>card.style.getPropertyValue(v))
      };
      const observer=new MutationObserver(()=>{});
      observer.observe(card,{attributes:true,characterData:true,childList:true,subtree:true});
      clock.renderAt(now);
      const stableMutations=observer.takeRecords();
      observer.disconnect();
      const repeat={
        phase:card.dataset.phase,progress:progress(),countdown:countdown(),
        phaseLabel:select('progress-phase')?.textContent,
        aria:select('progress-track')?.getAttribute('aria-valuenow'),
        colors:['--stage-accent','--stage-soft','--stage-border','--stage-glow','--stage-text']
          .map(v=>card.style.getPropertyValue(v))
      };
      clock.renderAt(now+15000);
      const advanced={countdown:countdown(),progress:progress()};
      const blobs=[...document.querySelectorAll('.ambient-blob')];
      const animationNames=blobs.map(el=>getComputedStyle(el).animationName);
      return {baseline,repeat,advanced,stableMutationCount:stableMutations.length,
        stableMutationDetails:stableMutations.slice(0,8).map(m=>m.attributeName||m.type),
        blobCount:blobs.length,animationNames};
    }finally{
      clock.resume();
    }
  });
  expect(audit.repeat).toEqual(audit.baseline);
  expect(audit.stableMutationCount,JSON.stringify(audit.stableMutationDetails)).toBeLessThanOrEqual(2);
  const seconds=v=>v[0]*86400+v[1]*3600+v[2]*60+v[3];
  expect(seconds(audit.baseline.countdown)-seconds(audit.advanced.countdown)).toBe(15);
  expect(audit.advanced.progress).toBeGreaterThanOrEqual(audit.baseline.progress);
  expect(audit.blobCount).toBeGreaterThanOrEqual(8);
  expect(audit.animationNames.some(name=>name.includes('blobDrift'))).toBe(true);
});

test('obsolete historic cover is not preloaded before current cover while visual code stays intact',async({page,request})=>{
  await expect(page.locator('link[rel="preload"][as="image"][href*="41b7ffdb9e0bde66a24425c4"]')).toHaveCount(0);
  const html=await (await request.get('/?perf-audit='+Date.now(),{headers:{'cache-control':'no-cache'}})).text();
  expect(html).toContain('id:"dios-de-milagros"');
  expect(html).toContain('ab67616d0000b27341b7ffdb9e0bde66a24425c4');
  expect(html).toContain('@keyframes blobDrift1');
  expect(html).toContain('function getProgressPalette(song,now)');
  expect(html).toContain('function applyProgressPalette(song,now,card)');
  expect(html).toContain('ipcdj-performance-lite');
});
