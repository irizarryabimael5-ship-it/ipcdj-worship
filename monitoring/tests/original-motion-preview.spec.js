import { test, expect } from '@playwright/test';

test.describe('v193 opt-in historical Dios de Milagros motion (staging only)', () => {
  test.skip(({ }, testInfo) => testInfo.project.name !== 'chromium-desktop',
    'Dedicated computed-style and animation-progress proof uses desktop Chromium; full existing seven-profile matrix still runs');

  const snapshot = page => page.evaluate(() => {
    const root=document.documentElement;
    const blob=document.querySelector('.ambient-field-active .ambient-blob.b1');
    const fill=document.querySelector('[data-current-song-card] [data-role="progress-fill"]');
    const ambient=blob?getComputedStyle(blob):null;
    const sheen=fill?getComputedStyle(fill,'::after'):null;
    return {
      optIn:root.classList.contains('ipcdj-original-motion-preview'),
      reduced:matchMedia('(prefers-reduced-motion: reduce)').matches,
      ambientName:ambient?.animationName||null,
      ambientState:ambient?.animationPlayState||null,
      sheenName:sheen?.animationName||null,
      sheenState:sheen?.animationPlayState||null,
      tabs:[...document.querySelectorAll('.site-tab')].map(t=>({
        id:t.id,label:t.textContent.trim()
      })),
      songs:[...document.querySelectorAll('[data-current-song-card]')].map(c=>c.dataset.songId),
      build:document.querySelector('meta[name="ipcdj-build"]')?.content,
      noHorizontalOverflow:document.documentElement.scrollWidth<=innerWidth+4,
      reportVisible:!!document.getElementById('ipcdj-motion-report')
    };
  });

  test('keeps reduced-motion accessibility intact without opt-in', async ({ page }) => {
    await page.emulateMedia({ reducedMotion:'reduce' });
    await page.goto('/?motion_report=1', { waitUntil:'domcontentloaded' });
    await page.waitForFunction(() => !!document.querySelector('[data-current-song-card] [data-role="progress-fill"]'));
    const s=await snapshot(page);
    expect(s.optIn).toBe(false);
    expect(s.reduced).toBe(true);
    expect(s.ambientName).toBe('none');
    expect(s.sheenName).toBe('none');
    expect(s.build).toBe('campana-weekend-v193');
    expect(s.reportVisible).toBe(true);
    expect(s.noHorizontalOverflow).toBe(true);
  });

  test('original motion restores live ambient and white bar sheen without changing tabs or songs', async ({ page }) => {
    await page.emulateMedia({ reducedMotion:'reduce' });
    await page.goto('/?motion_report=1', { waitUntil:'domcontentloaded' });
    await page.waitForFunction(() => !!document.querySelector('[data-current-song-card] [data-role="progress-fill"]'));
    const baseline=await snapshot(page);
    await page.goto('/?visual=original&motion_report=1', { waitUntil:'domcontentloaded' });
    await page.waitForFunction(() => !!document.querySelector('[data-current-song-card] [data-role="progress-fill"]'));
    const original=await snapshot(page);
    expect(original.reduced).toBe(true);
    expect(original.optIn).toBe(true);
    expect(original.ambientName).toContain('blobDrift1');
    expect(original.ambientState).toContain('running');
    expect(original.sheenName).toBe('progress-sheen');
    expect(original.sheenState).toBe('running');
    expect(original.tabs).toEqual(baseline.tabs);
    expect(original.songs).toEqual(baseline.songs);
    expect(original.noHorizontalOverflow).toBe(true);
    expect(original.reportVisible).toBe(true);
    await expect(page.locator('#ipcdj-motion-report-data')).toContainText('Vista original: true', { timeout:12000 });
    await expect(page.locator('#ipcdj-motion-report-data')).toContainText('Brillo: progress-sheen');

    // Verify actual animation timeline advancement, not merely CSS text.
    const readTime=()=>page.evaluate(()=>{
      const el=document.querySelector('.ambient-field-active .ambient-blob.b1');
      const a=el?.getAnimations().find(x=>x.animationName==='blobDrift1');
      return a&&typeof a.currentTime==='number'?a.currentTime:null;
    });
    const t0=await readTime();
    expect(t0).not.toBeNull();
    await expect.poll(readTime, { timeout:10000, intervals:[700,900,1300] }).toBeGreaterThan(t0+300);
  });
  test('the first visible Prep card is the only ambient palette owner', async ({ page }) => {
    await page.goto('/?visual=original', { waitUntil:'domcontentloaded' });
    await page.waitForFunction(() => !!window.IPCDJ_CATALOG_TEST?.renderOverlapAt);
    const beforeTabs=await page.locator('.site-tab').evaluateAll(nodes=>nodes.map(x=>x.id));
    try {
      for (const when of [
        '2026-10-01T12:00:00-04:00',
        '2026-10-07T12:00:00-04:00',
        '2026-10-14T12:00:00-04:00'
      ]) {
        const sample=await page.evaluate(instant=>{
          const songs=window.IPCDJ_CATALOG_TEST.renderOverlapAt(Date.parse(instant));
          const cards=[...document.querySelectorAll('[data-current-song-card][data-song-id]')];
          return {
            renderedIds:cards.map(c=>c.dataset.songId),
            simulatedIds:songs.map(s=>s.id),
            phases:songs.map(s=>s.phase),
            driver:document.documentElement.dataset.ambientDriverSongId
          };
        },when);
        expect(sample.renderedIds).toEqual(sample.simulatedIds);
        expect(sample.renderedIds.length).toBe(2);
        expect(sample.driver).toBe(sample.renderedIds[0]);
      }
      expect(await page.locator('.site-tab').evaluateAll(nodes=>nodes.map(x=>x.id))).toEqual(beforeTabs);
    } finally {
      await page.evaluate(()=>window.IPCDJ_CATALOG_TEST.resume());
    }
  });

});
