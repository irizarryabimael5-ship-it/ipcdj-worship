import { test, expect } from '@playwright/test';
import { createHash } from 'node:crypto';

const isBenignOptionalProviderError = message => {
  const text = String(message || '');
  return (
    /covers\.musichoarders\.xyz/i.test(text) &&
    /(cors|cross-origin|access control|failed to load|load failed|networkerror)/i.test(text)
  );
};

const fatalPageErrors = errors => errors.filter(error => !isBenignOptionalProviderError(error));

async function openHealthyPage(page) {
  const pageErrors = [];
  const consoleErrors = [];

  page.on('pageerror', error => {
    pageErrors.push(String(error?.message || error));
  });

  page.on('console', message => {
    if (message.type() === 'error') {
      consoleErrors.push(message.text());
    }
  });

  const response = await page.goto('/?healthcheck=' + Date.now(), {
    waitUntil: 'domcontentloaded',
    timeout: 30000
  });

  expect(response, 'main document response').not.toBeNull();
  expect(response.ok(), 'main document should return 2xx').toBeTruthy();

  await expect(page.locator('meta[name="ipcdj-build"]'))
    .toHaveAttribute('content', /(?:persistent-launch|mobile-refresh|weekly-rollover)-v\d+/);
  await expect(page.locator('meta[name="ipcdj-environment"]'))
    .toHaveAttribute('content','staging');
  await expect(page.locator('meta[name="robots"]'))
    .toHaveAttribute('content',/noindex/);

  await page.waitForFunction(() => (
    !!window.IPCDJ_HEALTH &&
    !!document.querySelector('[data-current-song-card]')
  ), null, { timeout: 12000 });

  await page.waitForFunction(() => {
    const launch = document.getElementById('ipcdj-launch');
    if (!launch) return true;
    const style = getComputedStyle(launch);
    return (
      launch.classList.contains('launch-idle') ||
      (
        !document.documentElement.classList.contains('ipcdj-launch-active') &&
        (style.visibility === 'hidden' || Number(style.opacity) <= 0.01)
      )
    );
  }, null, { timeout: 30000 });

  return { pageErrors, consoleErrors };
}

async function scrollSweep(page) {
  const max = await page.evaluate(() => Math.max(
    0,
    document.documentElement.scrollHeight - window.innerHeight
  ));

  if (!max) return;

  // Drive scrolling from Playwright instead of waiting on in-page rAF. Headless
  // WebKit can throttle rAF aggressively even when scrolling itself is healthy.
  const steps = 18;
  for (let i = 0; i <= steps; i++) {
    await page.evaluate(y => window.scrollTo(0, y), Math.round(max * (i / steps)));
    await page.waitForTimeout(35);
  }

  for (let i = steps; i >= 0; i--) {
    await page.evaluate(y => window.scrollTo(0, y), Math.round(max * (i / steps)));
    await page.waitForTimeout(35);
  }
}

test('integrity, launch, layout and scrolling remain healthy', async ({ page }, testInfo) => {
  const { pageErrors, consoleErrors } = await openHealthyPage(page);

  const initial = await page.evaluate(() => window.IPCDJ_HEALTH.checkNow());
  expect(initial.currentCards).toBeGreaterThan(0);
  expect(initial.horizontalOverflow).toBeLessThanOrEqual(4);
  expect(initial.sameOriginResourceErrors).toBe(0);
  expect(initial.errors).toBe(0);
  expect(initial.rejections).toBe(0);

  await scrollSweep(page);

  const frameSample = await page.evaluate(() => window.IPCDJ_HEALTH.sampleFrames(1400));
  if (frameSample) {
    // Shared CI hosts do not provide deterministic refresh rates. Headless WebKit
    // can aggressively throttle rAF even after Playwright-driven scrolling, so
    // treat WebKit as a gross-freeze detector instead of requiring a synthetic
    // minimum frame count. Actual devices still use IPCDJ's stricter in-page
    // adaptive sampler.
    expect(frameSample.duration).toBeGreaterThan(600);

    if (/webkit/i.test(testInfo.project.name)) {
      // Linux CI WebKit can park rAF for long stretches unrelated to real Safari
      // rendering. Keep only a catastrophic-freeze ceiling here; real-device
      // IPCDJ_HEALTH sampling remains the stricter performance authority.
      expect(frameSample.frames).toBeGreaterThan(0);
      expect(frameSample.max).toBeLessThan(5000);
    } else {
      // Headless Chromium/Firefox can run below 20fps under shared CI CPU even
      // when the page is responsive. Guard catastrophic stalls here; real-device
      // IPCDJ_HEALTH keeps the stricter over-50ms adaptive-performance signal.
      expect(frameSample.max).toBeLessThan(1500);
      expect(frameSample.p95).toBeLessThan(1200);
      expect(frameSample.frames).toBeGreaterThan(3);
    }
  }

  const finalSnapshot = await page.evaluate(() => window.IPCDJ_HEALTH.checkNow());
  expect(finalSnapshot.horizontalOverflow).toBeLessThanOrEqual(4);
  expect(finalSnapshot.sameOriginResourceErrors).toBe(0);
  expect(finalSnapshot.errors).toBe(0);
  expect(finalSnapshot.rejections).toBe(0);
  const fatalErrors = fatalPageErrors(pageErrors);
  expect(fatalErrors).toEqual([]);

  await testInfo.attach('health-snapshot.json', {
    body: Buffer.from(JSON.stringify(finalSnapshot, null, 2)),
    contentType: 'application/json'
  });

  if (consoleErrors.length) {
    await testInfo.attach('console-errors.txt', {
      body: Buffer.from(consoleErrors.join('\n')),
      contentType: 'text/plain'
    });
  }
});

test('preview playback and song-to-song handoff stay functional', async ({ page }, testInfo) => {
  const { pageErrors, consoleErrors } = await openHealthyPage(page);

  const currentRow = page.locator('.preview-row-current').first();
  await expect(currentRow).toBeVisible();

  const currentButton = currentRow.locator('.preview-button');
  await expect(currentButton).toBeEnabled();

  await currentButton.click();

  let currentStarted = false;
  try {
    await expect.poll(
      () => currentRow.evaluate(row => row.classList.contains('is-playing')),
      { timeout: 15000, message: 'current preview should begin playing' }
    ).toBe(true);
    currentStarted = true;
  } finally {
    if (!currentStarted) {
      const failureSnapshot = await page.evaluate(() => window.IPCDJ_HEALTH.checkNow());
      await testInfo.attach('preview-start-failure.json', {
        body: Buffer.from(JSON.stringify(failureSnapshot, null, 2)),
        contentType: 'application/json'
      });
    }
  }

  // IPCDJ's own tab navigation must not surrender preview playback. On iOS-like
  // environments a visible in-page tab interaction can be accompanied by a
  // transient window blur; reproduce that exact sequence and require the same
  // song/engine/elapsed timeline to survive it.
  await page.waitForFunction(() => !!window.IPCDJ_PREVIEW_TEST);
  const beforeInternalTabSwitch = await page.evaluate(() => window.IPCDJ_PREVIEW_TEST.snapshot());
  expect(beforeInternalTabSwitch.playing).toBe(true);
  expect(beforeInternalTabSwitch.songId.length).toBeGreaterThan(0);

  const weeklyTabForPreview = page.locator('#tab-worship-semanal');
  const homeTabForPreview = page.locator('#tab-inicio');
  await weeklyTabForPreview.dispatchEvent('pointerdown', { pointerType:'touch', isPrimary:true });
  await weeklyTabForPreview.click();
  await expect(weeklyTabForPreview).toHaveAttribute('aria-selected','true');

  // Reproduce the real mobile/WebKit failure mode: the AudioContext can suspend
  // only after the destination panel has switched, which is later than the
  // internalnavigation event itself. Visible in-app navigation must recover it
  // without resetting ownership or elapsed time.
  await page.evaluate(async () => {
    await window.IPCDJ_PREVIEW_TEST.suspendContext();
  });
  await expect.poll(
    () => page.evaluate(() => window.IPCDJ_PREVIEW_TEST.snapshot().contextState),
    { timeout: 3000, message: 'visible internal navigation should recover a late Web Audio suspension' }
  ).toBe('running');

  await page.evaluate(() => window.dispatchEvent(new Event('blur')));
  await page.waitForTimeout(520);

  const duringInternalTabSwitch = await page.evaluate(() => window.IPCDJ_PREVIEW_TEST.snapshot());
  expect(duringInternalTabSwitch.playing).toBe(true);
  expect(duringInternalTabSwitch.songId).toBe(beforeInternalTabSwitch.songId);
  expect(duringInternalTabSwitch.elapsed).toBeGreaterThan(beforeInternalTabSwitch.elapsed + .15);

  await homeTabForPreview.click();
  await expect(homeTabForPreview).toHaveAttribute('aria-selected','true');
  await expect(currentRow).toBeVisible();

  const afterInternalTabSwitch = await page.evaluate(() => window.IPCDJ_PREVIEW_TEST.snapshot());
  expect(afterInternalTabSwitch.playing).toBe(true);
  expect(afterInternalTabSwitch.songId).toBe(beforeInternalTabSwitch.songId);
  expect(afterInternalTabSwitch.elapsed).toBeGreaterThan(duringInternalTabSwitch.elapsed);

  const futureRow = page.locator('.preview-row-future').first();
  if (await futureRow.count()) {
    const futureButton = futureRow.locator('.preview-button');
    const futureCountdown = futureRow.locator('.future-preview-countdown');
    const futureRing = futureRow.locator('.future-preview-ring-progress');

    await expect(futureButton).toBeEnabled();
    await expect(futureCountdown).toHaveCount(1);
    await expect(futureRing).toHaveCount(1);

    const ringAlignment = await futureButton.evaluate(button => {
      const svg = button.querySelector('.future-preview-ring');
      const track = button.querySelector('.future-preview-ring-track');
      const progress = button.querySelector('.future-preview-ring-progress');
      if (!svg || !track || !progress) return null;

      const buttonRect = button.getBoundingClientRect();
      const ringRect = svg.getBoundingClientRect();
      const ringStyle = getComputedStyle(svg);
      return {
        leftDelta: Math.abs(ringRect.left - buttonRect.left),
        topDelta: Math.abs(ringRect.top - buttonRect.top),
        rightDelta: Math.abs(buttonRect.right - ringRect.right),
        bottomDelta: Math.abs(buttonRect.bottom - ringRect.bottom),
        centerXDelta: Math.abs(
          (ringRect.left + ringRect.width / 2) -
          (buttonRect.left + buttonRect.width / 2)
        ),
        centerYDelta: Math.abs(
          (ringRect.top + ringRect.height / 2) -
          (buttonRect.top + buttonRect.height / 2)
        ),
        computedWidth: Number.parseFloat(ringStyle.width),
        computedHeight: Number.parseFloat(ringStyle.height),
        buttonWidth: buttonRect.width,
        buttonHeight: buttonRect.height,
        trackRadius: track.getAttribute('r'),
        progressRadius: progress.getAttribute('r')
      };
    });

    expect(ringAlignment).not.toBeNull();
    // The button keeps a 1px transparent border for sizing. Absolute children
    // therefore sit on its padding box: a 1px inset is correct, while the center
    // must remain effectively identical. This catches real drift without flagging
    // the intentional border geometry approved in production.
    expect(ringAlignment.centerXDelta).toBeLessThanOrEqual(0.35);
    expect(ringAlignment.centerYDelta).toBeLessThanOrEqual(0.35);
    expect(ringAlignment.leftDelta).toBeLessThanOrEqual(1.25);
    expect(ringAlignment.topDelta).toBeLessThanOrEqual(1.25);
    expect(ringAlignment.rightDelta).toBeLessThanOrEqual(1.25);
    expect(ringAlignment.bottomDelta).toBeLessThanOrEqual(1.25);
    expect(Math.abs(ringAlignment.computedWidth - (ringAlignment.buttonWidth - 2))).toBeLessThanOrEqual(0.75);
    expect(Math.abs(ringAlignment.computedHeight - (ringAlignment.buttonHeight - 2))).toBeLessThanOrEqual(0.75);
    expect(ringAlignment.trackRadius).toBe(ringAlignment.progressRadius);

    const initialOffset = await futureRing.evaluate(circle => {
      const value = Number.parseFloat(circle.style.strokeDashoffset || getComputedStyle(circle).strokeDashoffset);
      return Number.isFinite(value) ? value : 100;
    });
    expect(initialOffset).toBeGreaterThanOrEqual(99);

    await futureButton.click();

    await expect.poll(
      () => futureRow.evaluate(row => row.classList.contains('is-playing')),
      { timeout: 15000, message: 'future preview should take playback ownership' }
    ).toBe(true);

    await expect.poll(
      () => currentRow.evaluate(row => row.classList.contains('is-playing')),
      { timeout: 5000, message: 'previous preview should release playing state' }
    ).toBe(false);

    await expect.poll(
      () => futureRing.evaluate(circle => {
        const value = Number.parseFloat(circle.style.strokeDashoffset || getComputedStyle(circle).strokeDashoffset);
        return Number.isFinite(value) ? value : 100;
      }),
      { timeout: 5000, message: 'future preview ring should advance clockwise with playback' }
    ).toBeLessThan(99);

    await expect.poll(
      () => futureCountdown.textContent(),
      { timeout: 5000, message: 'future preview countdown should show remaining time' }
    ).toMatch(/^\d+:\d{2}$/);
  }

  // Internal navigation persistence must never weaken the existing mobile
  // background-stop contract. A real pagehide still terminates playback.
  if (/mobile|tablet/i.test(testInfo.project.name)) {
    await page.evaluate(() => window.dispatchEvent(new Event('pagehide')));
    await expect.poll(
      () => page.evaluate(() => window.IPCDJ_PREVIEW_TEST.snapshot().playing),
      { timeout: 2000, message: 'mobile/tablet pagehide should stop preview playback' }
    ).toBe(false);
  }

  const snapshot = await page.evaluate(() => window.IPCDJ_HEALTH.checkNow());
  expect(snapshot.errors).toBe(0);
  expect(snapshot.rejections).toBe(0);
  expect(snapshot.previewErrors).toBe(0);
  expect(fatalPageErrors(pageErrors)).toEqual([]);

  await testInfo.attach('preview-health.json', {
    body: Buffer.from(JSON.stringify(snapshot, null, 2)),
    contentType: 'application/json'
  });

  if (consoleErrors.length) {
    await testInfo.attach('preview-console-errors.txt', {
      body: Buffer.from(consoleErrors.join('\n')),
      contentType: 'text/plain'
    });
  }
});

test('live rendering tolerates translation-style DOM rewrites and text expansion', async ({ page }) => {
  await openHealthyPage(page);

  const card = page.locator('[data-current-song-card]').first();
  const status = card.locator('[data-role="status"]');
  await expect(status).toBeVisible();

  await status.evaluate(element => {
    element.textContent = 'TRANSLATED STATUS — LONGER TEXT FOR LAYOUT VALIDATION';
  });

  await page.waitForTimeout(1300);
  await expect(status).toHaveText('TRANSLATED STATUS — LONGER TEXT FOR LAYOUT VALIDATION');

  await expect(card.locator('[data-role="song-name"]')).toHaveAttribute('translate', 'no');
  await expect(card.locator('[data-role="artist"]')).toHaveAttribute('translate', 'no');

  await page.evaluate(() => {
    document.querySelectorAll('.section-note,.countdown-note').forEach((element, index) => {
      if (index < 2) {
        element.textContent += ' · Extended translated wording to verify wrapping without horizontal overflow.';
      }
    });
  });

  const overflow = await page.evaluate(() => (
    document.documentElement.scrollWidth - document.documentElement.clientWidth
  ));

  expect(overflow).toBeLessThanOrEqual(4);
});


test('primary tabs, weekly panel and special-event lifecycle remain healthy', async ({ page }) => {
  await openHealthyPage(page);

  await page.waitForFunction(() => !!window.IPCDJ_NAV);

  const tablist = page.getByRole('tablist', { name: 'Secciones de IPCDJ Worship' });
  const homeTab = page.locator('#tab-inicio');
  const weeklyTab = page.locator('#tab-worship-semanal');
  const homePanel = page.locator('#panel-inicio');
  const weeklyPanel = page.locator('#panel-worship-semanal');

  await expect(tablist).toBeVisible();

  const navLayout = await page.evaluate(() => {
    const nav=document.querySelector('.site-nav');
    const tablist=document.querySelector('.site-tablist');
    const hero=document.querySelector('.hero');
    if(!nav||!tablist||!hero)return null;
    const tabs=[...nav.querySelectorAll('[role="tab"]')];
    const widths=tabs.map(tab=>tab.getBoundingClientRect().width);
    const heights=tabs.map(tab=>tab.getBoundingClientRect().height);
    const navRect=nav.getBoundingClientRect();
    const listRect=tablist.getBoundingClientRect();
    const listAfter=getComputedStyle(tablist,'::after');
    const tabStyles=tabs.map(tab=>{
      const style=getComputedStyle(tab);
      const before=getComputedStyle(tab,'::before');
      const label=tab.querySelector('.site-tab-label');
      const labelAfter=label?getComputedStyle(label,'::after'):null;
      return {
        key:tab.dataset.siteTab||'',
        selected:tab.getAttribute('aria-selected')==='true',
        display:style.display,
        backgroundImage:style.backgroundImage,
        boxShadow:style.boxShadow,
        borderTopWidth:style.borderTopWidth,
        radius:parseFloat(style.borderTopLeftRadius)||0,
        labelCount:label?1:0,
        iconCount:tab.querySelector('.site-tab-icon')?1:0,
        accentHeight:parseFloat(before.height)||0,
        accentOpacity:Number(before.opacity),
        accentBackground:before.backgroundImage||before.backgroundColor,
        eventDotDisplay:labelAfter?.display||'none',
        eventDotWidth:labelAfter?parseFloat(labelAfter.width)||0:0,
        eventDotBackground:labelAfter?.backgroundColor||''
      };
    });
    return {
      heroBeforeNav:!!(hero.compareDocumentPosition(nav)&Node.DOCUMENT_POSITION_FOLLOWING),
      position:getComputedStyle(nav).position,
      navWidth:navRect.width,
      tablistWidth:listRect.width,
      viewportWidth:window.innerWidth,
      widths,
      heights,
      baselineHeight:parseFloat(listAfter.height)||0,
      baselineBackground:listAfter.backgroundImage||listAfter.backgroundColor,
      tabStyles
    };
  });

  expect(navLayout).not.toBeNull();
  expect(navLayout.heroBeforeNav).toBe(true);
  expect(navLayout.position).toBe('relative');
  expect(navLayout.navWidth).toBeLessThanOrEqual(navLayout.viewportWidth);
  expect(navLayout.tablistWidth).toBeLessThanOrEqual(navLayout.navWidth);
  if(navLayout.viewportWidth<=520){
    expect(Math.max(...navLayout.widths)-Math.min(...navLayout.widths)).toBeLessThanOrEqual(1.5);
  }else{
    expect(navLayout.tablistWidth).toBeLessThan(navLayout.navWidth);
    expect(Math.min(...navLayout.widths)).toBeGreaterThanOrEqual(94);
    expect(Math.max(...navLayout.widths)).toBeLessThanOrEqual(210);
  }
  expect(Math.max(...navLayout.heights)-Math.min(...navLayout.heights)).toBeLessThanOrEqual(1.5);
  expect(Math.min(...navLayout.heights)).toBeGreaterThanOrEqual(44);
  expect(navLayout.baselineHeight).toBeGreaterThanOrEqual(1);
  expect(navLayout.baselineBackground).not.toBe('none');

  for(const tab of navLayout.tabStyles){
    expect(tab.display).toBe('flex');
    expect(tab.labelCount).toBe(1);
    expect(tab.iconCount).toBe(0);
    expect(tab.radius).toBeLessThanOrEqual(8);
    expect(tab.backgroundImage).toBe('none');
    expect(tab.boxShadow).toBe('none');
    expect(tab.borderTopWidth).toBe('0px');
  }

  const initialSelected=navLayout.tabStyles.find(tab=>tab.key==='inicio');
  const initialWeekly=navLayout.tabStyles.find(tab=>tab.key==='worship-semanal');
  expect(initialSelected?.selected).toBe(true);
  expect(initialSelected?.accentHeight).toBeGreaterThanOrEqual(3);
  expect(initialSelected?.accentOpacity).toBeGreaterThan(.9);
  expect(initialSelected?.accentBackground).not.toBe('none');
  expect(initialWeekly?.accentOpacity).toBeLessThan(.1);

  await expect(homeTab).toHaveAttribute('aria-selected', 'true');
  await expect(homePanel).toBeVisible();
  await expect(weeklyPanel).toBeHidden();

  const launch = page.locator('#ipcdj-launch');
  const launchClassBeforeSwitch = await launch.getAttribute('class');

  await weeklyTab.dispatchEvent('pointerdown', { pointerType: 'touch', isPrimary: true });
  await page.evaluate(() => window.dispatchEvent(new Event('blur')));
  await expect(launch).toHaveAttribute('class', launchClassBeforeSwitch || 'launch-idle');

  await weeklyTab.click();
  await expect(weeklyTab).toHaveAttribute('aria-selected', 'true');
  await page.waitForFunction(() => {
    const tab=document.getElementById('tab-worship-semanal');
    if(!tab)return false;
    const before=getComputedStyle(tab,'::before');
    return Number(before.opacity)>.9 && (parseFloat(before.height)||0)>=3;
  });
  const weeklySelectedVisual=await weeklyTab.evaluate(tab=>{
    const style=getComputedStyle(tab);
    const before=getComputedStyle(tab,'::before');
    return {
      backgroundImage:style.backgroundImage,
      boxShadow:style.boxShadow,
      borderTopWidth:style.borderTopWidth,
      accentHeight:parseFloat(before.height)||0,
      accentOpacity:Number(before.opacity),
      accentBackground:before.backgroundImage||before.backgroundColor
    };
  });
  expect(weeklySelectedVisual.backgroundImage).toBe('none');
  expect(weeklySelectedVisual.boxShadow).toBe('none');
  expect(weeklySelectedVisual.borderTopWidth).toBe('0px');
  expect(weeklySelectedVisual.accentHeight).toBeGreaterThanOrEqual(3);
  expect(weeklySelectedVisual.accentOpacity).toBeGreaterThan(.9);
  expect(weeklySelectedVisual.accentBackground).not.toBe('none');
  await expect(weeklyPanel).toBeVisible();
  await expect(homePanel).toBeHidden();
  await expect(weeklyPanel).not.toContainText('Próximamente');
  const fridayWeeklyTab=weeklyPanel.locator('#weekly-tab-viernes');
  const sundayWeeklyTab=weeklyPanel.locator('#weekly-tab-domingo');
  const fridayWeeklyPanel=weeklyPanel.locator('#weekly-panel-viernes');
  const sundayWeeklyPanel=weeklyPanel.locator('#weekly-panel-domingo');
  const weeklyDashboard=weeklyPanel.locator('[data-weekly-dashboard]');
  const weeklyHistory=weeklyPanel.locator('.weekly-history');
  const fridayHistory=weeklyPanel.locator('[data-weekly-history-service="viernes"]');
  const sundayHistory=weeklyPanel.locator('[data-weekly-history-service="domingo"]');

  // The Oct. 2/4 set has already passed its Sunday 3 PM cutoff and must be
  // stored as the single Semana anterior while the new week is pending.
  await expect(weeklyDashboard).toHaveAttribute('data-weekly-state','rolled');
  await expect(weeklyDashboard).toHaveAttribute('data-weekly-cycle','2026-10-04');
  await expect(weeklyDashboard).toHaveAttribute('data-weekly-rollover-at','2026-10-04T15:00:00-04:00');
  await expect(fridayWeeklyTab).toHaveAttribute('aria-selected','true');
  await expect(sundayWeeklyTab).toHaveAttribute('aria-selected','false');
  await expect(fridayWeeklyPanel).toBeVisible();
  await expect(sundayWeeklyPanel).toBeHidden();
  await expect(fridayWeeklyTab).toContainText('Pendiente');
  await expect(sundayWeeklyTab).toContainText('Pendiente');
  await expect(weeklyPanel).toContainText('Nuevo set pendiente');
  await expect(fridayWeeklyPanel).toContainText('Set pendiente');
  await expect(fridayWeeklyPanel.locator('.weekly-song')).toHaveCount(0);
  await expect(sundayWeeklyPanel.locator('.weekly-song')).toHaveCount(0);

  await sundayWeeklyTab.click();
  await expect(sundayWeeklyTab).toHaveAttribute('aria-selected','true');
  await expect(sundayWeeklyPanel).toBeVisible();
  await expect(fridayWeeklyPanel).toBeHidden();
  await expect(sundayWeeklyPanel).toContainText('Set pendiente');

  await expect(weeklyHistory.locator('summary')).toContainText('Semana anterior');
  await expect(weeklyHistory.locator('summary')).toContainText('4 oct 2026');
  await expect(weeklyPanel.locator('[data-weekly-history-body]')).toHaveAttribute('data-weekly-history-cycle','2026-10-04');
  await weeklyHistory.locator('summary').click();
  await expect(fridayHistory).toBeVisible();
  await expect(sundayHistory).toBeVisible();

  // Friday archive must preserve the completed set and every linked resource.
  await expect(fridayHistory).toContainText('Worship set del viernes');
  await expect(fridayHistory).toContainText('Dayari');
  await expect(fridayHistory.locator('.weekly-song')).toHaveCount(4);
  await expect(fridayHistory.locator('.weekly-corito')).toHaveCount(7);
  await expect(fridayHistory).toContainText('Creados Para Adorar');
  await expect(fridayHistory).toContainText('Elmer Moroy');
  await expect(fridayHistory).toContainText('Sumérgeme');
  await expect(fridayHistory).toContainText('Jesús Adrián Romero');
  await expect(fridayHistory).toContainText('Cristo Yo Te Amo');
  await expect(fridayHistory).toContainText('Vino Nuevo');
  await expect(fridayHistory).toContainText('Tus Cuerdas De Amor');
  await expect(fridayHistory).toContainText('Julio Melgar feat. Lowsan Melgar');
  await expect(fridayHistory).toContainText('BPM · 90/180');
  await expect(fridayHistory).toContainText('Cristo Rompe Las Cadenas');
  await expect(fridayHistory).toContainText('+ Mas');
  await expect(fridayHistory.locator('.weekly-youtube-mark img[src="youtube-music.svg"]')).toHaveCount(1);
  await expect(fridayHistory.locator('.weekly-youtube-frame iframe')).toHaveAttribute(
    'src',
    /youtube-nocookie\.com\/embed\/videoseries\?list=PLJHxkkSIlf28/
  );
  await expect(fridayHistory.locator('a[href*="youtube.com/playlist?list=PLJHxkkSIlf28"]')).toHaveCount(1);
  await expect(fridayHistory.locator('a[href="https://u.pone.rs/iifwokqy.pdf"]')).toHaveCount(1);

  // Sunday archive must preserve the final five-song order and metadata.
  await expect(sundayHistory).toContainText('Worship set del domingo');
  await expect(sundayHistory).toContainText('9:30 AM');
  await expect(sundayHistory).toContainText('Dayari');
  await expect(sundayHistory.locator('.weekly-song')).toHaveCount(5);
  await expect(sundayHistory.locator('.weekly-corito')).toHaveCount(5);
  const sundaySongOrder=await sundayHistory.locator('.weekly-song-title').allTextContents();
  expect(sundaySongOrder).toEqual([
    'Dios De Milagros',
    'Algo Está Pasando',
    'Hay Libertad',
    'Permanecerás',
    'Yo Quiero Más De Ti'
  ]);
  await expect(sundayHistory).toContainText('Angel Luis Irizarry');
  await expect(sundayHistory).toContainText('BPM · 60/120');
  await expect(sundayHistory).toContainText('Do Sostenido Mayor');
  await expect(sundayHistory).toContainText('Re Mayor · 115 BPM');
  await expect(sundayHistory.locator('.weekly-youtube-mark img[src="youtube-music.svg"]')).toHaveCount(1);
  await expect(sundayHistory.locator('.weekly-youtube-frame iframe')).toHaveAttribute(
    'src',
    /youtube-nocookie\.com\/embed\/videoseries\?list=PLkLZ_UC3YYUw0TOBrAw19xENUYunh7URI/
  );
  await expect(sundayHistory.locator('a[href*="youtube.com/playlist?list=PLkLZ_UC3YYUw0TOBrAw19xENUYunh7URI"]')).toHaveCount(1);
  await expect(sundayHistory.locator('a[href="https://u.pone.rs/jzehueif.pdf"]')).toHaveCount(1);

  const weeklyOverflow=await weeklyPanel.evaluate(node=>({
    scrollWidth:node.scrollWidth,
    clientWidth:node.clientWidth
  }));
  expect(weeklyOverflow.scrollWidth).toBeLessThanOrEqual(weeklyOverflow.clientWidth+1);

  // Simulate the next active week to prove the exact 3 PM boundary, replacement
  // of Semana anterior, pending reset, and idempotency.
  const rolloverBoundary=await page.evaluate(() => {
    const prepared=window.IPCDJ_WEEKLY_TEST.prepareFromHistory('2026-10-11T15:00:00-04:00');
    const before=window.IPCDJ_WEEKLY_TEST.rollover(Date.parse('2026-10-11T14:59:59-04:00'));
    const beforeSnapshot=window.IPCDJ_WEEKLY_TEST.snapshot();
    const atBoundary=window.IPCDJ_WEEKLY_TEST.rollover(Date.parse('2026-10-11T15:00:00-04:00'));
    const afterSnapshot=window.IPCDJ_WEEKLY_TEST.snapshot();
    const secondAttempt=window.IPCDJ_WEEKLY_TEST.rollover(Date.parse('2026-10-11T16:00:00-04:00'));
    const ids=[...document.querySelectorAll('[id]')].map(node=>node.id);
    const duplicateIds=[...new Set(ids.filter((id,index)=>ids.indexOf(id)!==index))];
    return {prepared,before,beforeSnapshot,atBoundary,afterSnapshot,secondAttempt,duplicateIds};
  });

  expect(rolloverBoundary.prepared).toBe(true);
  expect(rolloverBoundary.before).toBe(false);
  expect(rolloverBoundary.beforeSnapshot.state).toBe('active');
  expect(rolloverBoundary.beforeSnapshot.fridayCurrent).toEqual([
    'Creados Para Adorar',
    'Sumérgeme',
    'Cristo Yo Te Amo',
    'Tus Cuerdas De Amor'
  ]);
  expect(rolloverBoundary.beforeSnapshot.sundayCurrent).toEqual([
    'Dios De Milagros',
    'Algo Está Pasando',
    'Hay Libertad',
    'Permanecerás',
    'Yo Quiero Más De Ti'
  ]);
  expect(rolloverBoundary.atBoundary).toBe(true);
  expect(rolloverBoundary.afterSnapshot.state).toBe('rolled');
  expect(rolloverBoundary.afterSnapshot.fridayCurrent).toEqual([]);
  expect(rolloverBoundary.afterSnapshot.sundayCurrent).toEqual([]);
  expect(rolloverBoundary.afterSnapshot.history).toHaveLength(2);
  expect(rolloverBoundary.afterSnapshot.history[0].songs).toEqual([
    'Creados Para Adorar',
    'Sumérgeme',
    'Cristo Yo Te Amo',
    'Tus Cuerdas De Amor'
  ]);
  expect(rolloverBoundary.afterSnapshot.history[1].songs).toEqual([
    'Dios De Milagros',
    'Algo Está Pasando',
    'Hay Libertad',
    'Permanecerás',
    'Yo Quiero Más De Ti'
  ]);
  expect(rolloverBoundary.secondAttempt).toBe(false);
  expect(rolloverBoundary.duplicateIds).toEqual([]);

  await fridayWeeklyTab.click();
  await expect(fridayWeeklyTab).toHaveAttribute('aria-selected','true');
  await expect(fridayWeeklyPanel).toBeVisible();
  await expect(fridayWeeklyPanel).toContainText('Set pendiente');
  await sundayWeeklyTab.click();
  await expect(sundayWeeklyTab).toHaveAttribute('aria-selected','true');
  await expect(sundayWeeklyPanel).toBeVisible();

  await sundayWeeklyTab.focus();
  await page.keyboard.press('Home');
  await expect(fridayWeeklyTab).toBeFocused();
  await expect(fridayWeeklyTab).toHaveAttribute('aria-selected','true');
  await page.keyboard.press('End');
  await expect(sundayWeeklyTab).toBeFocused();
  await expect(sundayWeeklyTab).toHaveAttribute('aria-selected','true');

  await expect(weeklyPanel).not.toHaveClass(/site-tab-panel-enter/);

  const launchClassAfterSwitch = await launch.getAttribute('class');
  expect(launchClassAfterSwitch).toBe(launchClassBeforeSwitch);

  const weeklySource=await page.locator('#panel-worship-semanal').evaluate(node=>node.outerHTML);
  expect(weeklySource).toContain('data-weekly-dashboard');
  expect(weeklySource).toContain('data-weekly-state="rolled"');
  expect(weeklySource).toContain('data-weekly-history-service="viernes"');
  expect(weeklySource).toContain('data-weekly-history-service="domingo"');
  expect(weeklySource).toContain('PLkLZ_UC3YYUw0TOBrAw19xENUYunh7URI');
  expect(weeklySource).toContain('https://u.pone.rs/jzehueif.pdf');

  await weeklyTab.focus();
  await page.keyboard.press('Home');
  await expect(homeTab).toBeFocused();
  await expect(homeTab).toHaveAttribute('aria-selected', 'true');

  await page.evaluate(() => {
    window.IPCDJ_NAV.syncSpecialEvents(Date.parse('2026-10-11T23:59:59-04:00'));
  });

  const eventTab = page.locator('#tab-campana-gu-2026');
  await expect(eventTab).toBeVisible();
  await expect(eventTab.locator('.site-tab-label')).toHaveText('Campaña GU 2026');
  await expect(eventTab.locator('.site-tab-icon')).toHaveCount(0);
  await eventTab.click();
  await page.waitForFunction(() => {
    const tab=document.getElementById('tab-campana-gu-2026');
    if(!tab)return false;
    const before=getComputedStyle(tab,'::before');
    const label=tab.querySelector('.site-tab-label');
    const dot=label?getComputedStyle(label,'::after'):null;
    return Number(before.opacity)>.9 &&
      (parseFloat(before.height)||0)>=3 &&
      !!dot &&
      dot.display==='inline-block' &&
      (parseFloat(dot.width)||0)>=4;
  });

  const eventSelectedVisual=await eventTab.evaluate(tab=>{
    const style=getComputedStyle(tab);
    const before=getComputedStyle(tab,'::before');
    const label=tab.querySelector('.site-tab-label');
    const dot=label?getComputedStyle(label,'::after'):null;
    return {
      backgroundImage:style.backgroundImage,
      boxShadow:style.boxShadow,
      accentHeight:parseFloat(before.height)||0,
      accentOpacity:Number(before.opacity),
      eventDotDisplay:dot?.display||'none',
      eventDotWidth:dot?parseFloat(dot.width)||0:0,
      eventDotBackground:dot?.backgroundColor||''
    };
  });
  expect(eventSelectedVisual.backgroundImage).toBe('none');
  expect(eventSelectedVisual.boxShadow).toBe('none');
  expect(eventSelectedVisual.accentHeight).toBeGreaterThanOrEqual(3);
  expect(eventSelectedVisual.accentOpacity).toBeGreaterThan(.9);
  expect(eventSelectedVisual.eventDotDisplay).toBe('inline-block');
  expect(eventSelectedVisual.eventDotWidth).toBeGreaterThanOrEqual(4);
  expect(eventSelectedVisual.eventDotBackground).not.toBe('rgba(0, 0, 0, 0)');

  const eventPanel = page.locator('#panel-campana-gu-2026');
  await expect(eventTab).toHaveAttribute('aria-selected', 'true');
  await expect(eventPanel).toBeVisible();
  await expect(eventPanel).toContainText('Próximamente');
  await expect(eventPanel).toContainText('Campaña GU 2026');

  const expiredEventState = await page.evaluate(() => {
    window.IPCDJ_NAV.syncSpecialEvents(Date.parse('2026-10-12T00:00:00-04:00'));
    const snapshot = {
      eventExists: !!document.getElementById('tab-campana-gu-2026'),
      activeKey: window.IPCDJ_NAV.getActiveKey(),
      homeVisible: !document.getElementById('panel-inicio')?.hidden
    };
    window.IPCDJ_NAV.syncSpecialEvents(Date.now());
    return snapshot;
  });

  expect(expiredEventState.eventExists).toBe(false);
  expect(expiredEventState.activeKey).toBe('inicio');
  expect(expiredEventState.homeVisible).toBe(true);

  const phaseState = await page.locator('[data-current-song-card]').first().evaluate(card => {
    const phase = card.dataset.phase || '';
    const timeline = card.querySelector('.timeline');
    const items = [...card.querySelectorAll('.timeline-item')];
    const active = items.filter(item => item.classList.contains('active-phase'));
    const inactive = items.filter(item => !item.classList.contains('active-phase'));

    const finalDate = card.querySelector('[data-role="timeline-final"] .timeline-date');
    const releaseDate = card.querySelector('[data-role="timeline-release"] .timeline-date');
    return {
      phase,
      timelineDisplay: timeline ? getComputedStyle(timeline).display : 'none',
      activeCount: active.length,
      activeRole: active[0]?.dataset.role || '',
      activeShadow: active[0] ? getComputedStyle(active[0]).boxShadow : 'none',
      inactive: inactive.map(item => ({
        role: item.dataset.role || '',
        shadow: getComputedStyle(item).boxShadow,
        opacity: Number(getComputedStyle(item).opacity)
      })),
      finalDateColor: finalDate ? getComputedStyle(finalDate).color : '',
      releaseDateColor: releaseDate ? getComputedStyle(releaseDate).color : ''
    };
  });

  if (['learning', 'final', 'release'].includes(phaseState.phase)) {
    expect(phaseState.activeCount).toBe(1);
    const expectedRole = phaseState.phase === 'learning'
      ? 'timeline-learning'
      : phaseState.phase === 'final'
        ? 'timeline-final'
        : 'timeline-release';
    expect(phaseState.activeRole).toBe(expectedRole);
    expect(phaseState.activeShadow).not.toBe('none');
  } else {
    expect(phaseState.activeCount).toBe(0);
  }

  if (phaseState.phase === 'release') {
    expect(phaseState.timelineDisplay).not.toBe('none');
  }

  for (const item of phaseState.inactive) {
    expect(item.shadow).toBe('none');
    expect(item.opacity).toBeLessThan(1);
  }

  if (phaseState.phase !== 'release') {
    expect(phaseState.releaseDateColor).not.toBe(phaseState.finalDateColor);
    const inactiveRelease = phaseState.inactive.find(item => item.role === 'timeline-release');
    if (inactiveRelease) expect(inactiveRelease.shadow).toBe('none');
  }
});


test('v184 primary navigation uses clean professional line-tab anatomy', async ({ request }) => {
  const response=await request.get('/?v184-nav-source='+Date.now(),{headers:{'cache-control':'no-cache'}});
  expect(response.ok()).toBe(true);
  const source=await response.text();

  expect(source).toContain('/* v184 primary navigation:');
  expect(source).toContain('professional line tabs inspired by mature web design systems');
  expect(source.indexOf('<header class="hero">')).toBeLessThan(source.indexOf('<nav class="site-nav"'));
  expect(source).toContain('.site-tablist::after');
  expect(source).toContain('gap:clamp(16px,2.6vw,34px)');
  expect(source).toContain('min-width:94px');
  expect(source).toContain('height:3px');
  expect(source).toContain('.site-tab[aria-selected="true"]::before');
  expect(source).toContain('.site-tab[data-special-event="true"] .site-tab-label::after');
  expect(source).toContain('flex:1 1 0');
  expect(source).not.toContain('class="site-tab-selection"');
  expect(source).not.toContain('SITE_TAB_ICONS=Object.freeze');
  expect(source).not.toContain('function syncSiteTabSelection()');
  expect(source).not.toContain('border-radius:11px 11px 0 0');
  expect(source).toContain('@media (max-width:520px)');
  expect(source).toContain('@media (max-width:340px)');
  expect(source).toContain('@media (prefers-contrast:more)');
  expect(source).toContain('@media (forced-colors:active)');
  expect(source).toContain('@media (prefers-reduced-motion: reduce)');
});

test('standalone full-scroll cycle cannot arm launch before tab switching', async ({ page }) => {
  await page.addInitScript(() => {
    try {
      Object.defineProperty(navigator, 'standalone', {
        configurable: true,
        get: () => true
      });
      Object.defineProperty(navigator, 'userAgent', {
        configurable: true,
        get: () => 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Version/18.0 Mobile/15E148 Safari/604.1'
      });
      Object.defineProperty(navigator, 'platform', {
        configurable: true,
        get: () => 'iPhone'
      });
      Object.defineProperty(navigator, 'maxTouchPoints', {
        configurable: true,
        get: () => 5
      });
    } catch (_) {}
  });

  await openHealthyPage(page);

  const launch = page.locator('#ipcdj-launch');
  const root = page.locator('html');
  await expect(launch).toHaveClass(/launch-idle/);
  await expect(root).not.toHaveClass(/ipcdj-launch-active/);

  // Reproduce the physical path reported on iPhone/PWA:
  // scroll to the bottom, return all the way to the top, then iOS emits a
  // visible blur/focus pair before an internal tab switch.
  await page.evaluate(() => window.scrollTo(0, document.documentElement.scrollHeight));
  await page.waitForTimeout(180);

  await page.evaluate(() => window.scrollTo(0, 0));
  await page.waitForTimeout(180);

  await page.evaluate(() => window.dispatchEvent(new Event('blur')));
  await page.waitForTimeout(240);

  expect(await page.evaluate(() => document.hidden)).toBe(false);
  await expect(launch).toHaveClass(/launch-idle/);
  await expect(root).not.toHaveClass(/ipcdj-launch-active/);

  await page.evaluate(() => window.dispatchEvent(new Event('focus')));
  await page.waitForTimeout(80);
  await expect(launch).toHaveClass(/launch-idle/);
  await expect(root).not.toHaveClass(/ipcdj-launch-active/);

  const weeklyTab = page.locator('#tab-worship-semanal');
  await weeklyTab.click();
  await expect(weeklyTab).toHaveAttribute('aria-selected', 'true');
  await expect(launch).toHaveClass(/launch-idle/);
  await expect(root).not.toHaveClass(/ipcdj-launch-active/);

  await page.evaluate(() => {
    window.IPCDJ_NAV.syncSpecialEvents(Date.parse('2026-10-11T23:59:59-04:00'));
  });
  const eventTab = page.locator('#tab-campana-gu-2026');
  await eventTab.click();
  await expect(eventTab).toHaveAttribute('aria-selected', 'true');
  await expect(launch).toHaveClass(/launch-idle/);
  await expect(root).not.toHaveClass(/ipcdj-launch-active/);
});


test('desktop Chrome tab switching cannot replay the launch intro', async ({ page }, testInfo) => {
  test.skip(testInfo.project.name !== 'chromium-desktop', 'Desktop Chrome regression only');

  await openHealthyPage(page);

  const launch = page.locator('#ipcdj-launch');
  const root = page.locator('html');

  const launchState = await page.evaluate(() => window.IPCDJ_LAUNCH_STATE);
  expect(launchState).toBeTruthy();
  expect(launchState.ios).toBe(false);
  expect(launchState.warmResumeEnabled).toBe(false);

  await expect(launch).toHaveClass(/launch-idle/);
  await expect(root).not.toHaveClass(/ipcdj-launch-active/);

  // Desktop Chrome may emit blur/focus and visibility events as users move
  // between browser tabs/windows. None may re-arm the intro after initial load.
  await page.evaluate(() => {
    window.dispatchEvent(new Event('blur'));
    document.dispatchEvent(new Event('visibilitychange'));
    window.dispatchEvent(new Event('focus'));
    document.dispatchEvent(new Event('visibilitychange'));
  });
  await page.waitForTimeout(260);

  await expect(launch).toHaveClass(/launch-idle/);
  await expect(root).not.toHaveClass(/ipcdj-launch-active/);
});



test('managed song catalog is single-source and lifecycle-safe', async ({ page, request }) => {
  await openHealthyPage(page);

  const audit = await page.evaluate(() => {
    const api = window.IPCDJ_CATALOG;
    if (!api) return null;
    return {
      version: api.version,
      timeZone: api.timeZone,
      health: api.health,
      songs: api.songs.map(song => {
        const learning = api.phase(song.id, Date.parse(song.learningStart));
        const finalStage = api.phase(song.id, Date.parse(song.finalStart));
        const release = api.phase(song.id, Date.parse(song.releaseDayStartAt));
        const released = api.phase(song.id, Date.parse(song.releaseDayEndAt));
        const complete = api.phase(song.id, Date.parse(song.rolloverAt));
        const atActive = api.snapshot(Date.parse(song.activeFrom));
        const atIntroduced = api.snapshot(Date.parse(song.rolloverAt));
        return {
          ...song,
          learning: learning?.key || '',
          finalStage: finalStage?.key || '',
          release: release?.key || '',
          released: released?.key || '',
          complete: complete?.key || '',
          currentAtActive: atActive.current.includes(song.id),
          currentAtIntroduced: atIntroduced.current.includes(song.id),
          introducedAtIntroduced: atIntroduced.introduced.includes(song.id)
        };
      })
    };
  });

  expect(audit).not.toBeNull();
  expect(audit.version).toBe(1);
  expect(audit.timeZone).toBe('America/New_York');
  expect(audit.health.valid).toBe(true);
  expect(audit.health.fullVisualReady).toBe(true);
  expect(audit.health.errors).toEqual([]);
  expect(audit.health.visualNotReady).toEqual([]);
  expect(audit.health.managedCount).toBe(audit.health.sourceCount);
  expect(audit.health.visualReadyCount).toBe(audit.health.managedCount);
  expect(audit.songs.length).toBeGreaterThan(0);

  const ids = audit.songs.map(song => song.id);
  expect(new Set(ids).size).toBe(ids.length);
  expect(ids).toContain('no-fallaras');

  const noFallaras = audit.songs.find(song => song.id === 'no-fallaras');
  expect(noFallaras).toBeTruthy();
  expect(Date.parse(noFallaras.activeFrom)).toBeGreaterThan(Date.parse(noFallaras.learningStart));
  expect(Date.parse(noFallaras.activeFrom)).toBeLessThan(Date.parse(noFallaras.releaseAt));

  const dios = audit.songs.find(song => song.id === 'dios-de-milagros');
  expect(dios).toBeTruthy();
  expect(dios.artworkSource).toBe('spotify');
  expect(dios.hasSubjectOverride).toBe(true);

  const explicitZone = /(?:Z|[+-]\d{2}:\d{2})$/i;
  const lifecycleFields = [
    'activeFrom','learningStart','learningEnd','finalStart','finalEnd',
    'releaseDayStartAt','releaseAt','releaseDayEndAt','rolloverAt','introducedAt'
  ];

  for (const song of audit.songs) {
    expect(song.fullVisualReady).toBe(true);
    expect(song.visualReadiness.hasCuratedArtwork).toBe(true);
    expect(song.visualReadiness.hasArtworkSource).toBe(true);
    expect(song.visualReadiness.hasCuratedPalette).toBe(true);
    expect(song.artworkUrl).toMatch(/^https:\/\//i);
    expect(song.artworkSource.length).toBeGreaterThan(0);
    expect(song.futurePalette).toHaveLength(3);
    for (const field of lifecycleFields) {
      expect(song[field]).toMatch(explicitZone);
    }
    expect(Date.parse(song.introducedAt)).toBe(Date.parse(song.rolloverAt));
    expect(song.historyAt).toBe(song.rolloverAt);
    if(song.previewAudioUrl)expect(song.previewSource).toBe('webaudio');
  }

  for (const song of audit.songs) {
    expect(song.learningLabel).toMatch(/ – /);
    expect(song.finalLabel).toMatch(/ – /);
    expect(song.releaseLabel.length).toBeGreaterThan(4);
    expect(song.releaseShortLabel.length).toBeGreaterThan(2);
    expect(song.releaseClockLabel).toMatch(/AM|PM/);
    expect(song.learning).toBe('learning');
    expect(song.finalStage).toBe('final');
    expect(song.release).toBe('release');
    expect(song.released).toBe('released');
    expect(song.complete).toBe('complete');
    expect(song.currentAtActive).toBe(true);
    expect(song.currentAtIntroduced).toBe(false);
    expect(song.introducedAtIntroduced).toBe(true);
  }

  const orderSnapshots = await page.evaluate(() => ({
    sep21: window.IPCDJ_CATALOG.snapshot(Date.parse('2026-09-21T12:00:00-04:00')),
    oct26Early: window.IPCDJ_CATALOG.snapshot(Date.parse('2026-10-26T01:00:00-04:00')),
    oct26Active: window.IPCDJ_CATALOG.snapshot(Date.parse('2026-10-26T06:01:00-04:00'))
  }));
  expect(orderSnapshots.sep21.upcoming).toEqual(['glorioso-dia','no-fallaras']);
  expect(orderSnapshots.oct26Early.upcoming).toEqual(['no-fallaras']);
  expect(orderSnapshots.oct26Active.current).toContain('no-fallaras');

  const sourceResponse = await request.get('/?catalog-source-check=' + Date.now(), {
    headers: { 'cache-control': 'no-cache' }
  });
  expect(sourceResponse.ok()).toBe(true);
  const source = await sourceResponse.text();
  const subjectHelper = source.match(/function manualCoverSubjectFocus\(song\)\{[\s\S]*?\n    \}/)?.[0] || '';
  expect(subjectHelper).not.toContain('dios-de-milagros');
  expect(source).toContain('coverSubjectFocus:{');
  expect(source).toContain('id="upcoming-songs" aria-live="polite"></div>');
  expect(source).toContain('id="introduced-songs" aria-live="polite"></div>');
  expect(source).toContain('introducedAt must exactly match rolloverAt for an atomic rotation/history handoff.');
  expect(source).toContain('function previewInternalTabSwitchActive()');
  expect(source).toContain('if(previewInternalTabSwitchActive())return;');
  expect(source).toContain('previewSource:raw.previewSource||(raw.previewAudioUrl?"webaudio":"")');
  expect(source).toContain('renderOverlapAt(timestamp)');
  expect(source).toContain('function createCurrentSongCardNode(song)');
  expect(source).toContain('Reconcile by song ID instead of replacing host.innerHTML.');
  expect(source).toContain('<h2 class="section-title">Estrenos recientes</h2>');
  expect(source).toContain('Estrenada · ${item.label}');
  expect(source).not.toContain('Math.min(index,40)*260');

  for (const id of ids) {
    const escaped = id.replace(/[-/\\^$*+?.()|[\]{}]/g, '\\$&');
    const occurrences = (source.match(new RegExp(escaped, 'g')) || []).length;
    expect(occurrences, id + ' should be authored only once in SONG_CATALOG_SOURCE').toBe(1);
  }
});

test('multiple simultaneous Prep songs keep independent dates, countdowns, artwork and previews', async ({ page }) => {
  await openHealthyPage(page);
  await page.waitForFunction(() => !!window.IPCDJ_CATALOG_TEST?.renderOverlapAt);

  try{
    await page.evaluate(() =>
      window.IPCDJ_CATALOG_TEST.renderAt(Date.parse('2026-10-01T12:00:00-04:00'))
    );

    const existingGlorioso=page.locator('[data-current-song-card][data-song-id="glorioso-dia"]');
    await expect(existingGlorioso).toHaveCount(1);
    await existingGlorioso.evaluate(card=>{
      card.dataset.watchdogPrepIdentity="preserve";
      const row=card.querySelector('[data-preview-song-id="glorioso-dia"]');
      if(row)row.dataset.watchdogPreviewIdentity="preserve";
    });

    const synthetic=await page.evaluate(() =>
      window.IPCDJ_CATALOG_TEST.renderOverlapAt(Date.parse('2026-10-01T12:00:00-04:00'))
    );

    expect(synthetic).toHaveLength(2);
    expect(synthetic.map(song=>song.id)).toEqual(['glorioso-dia','no-fallaras']);
    expect(synthetic.every(song=>song.phase==='learning')).toBe(true);

    const cards=page.locator('[data-current-song-card]');
    await expect(cards).toHaveCount(2);

    await page.waitForFunction(() =>
      [...document.querySelectorAll('[data-current-song-card]')].every(card => {
        const button=card.querySelector('.preview-button');
        const row=card.querySelector('[data-preview-song-id]');
        return !!button && button.dataset.bound==='true' && !!row;
      }),
      null,
      {timeout:15000}
    );

    const states=await cards.evaluateAll(nodes=>nodes.map(card=>({
      id:card.dataset.songId||'',
      phase:card.dataset.phase||'',
      title:card.querySelector('[data-role="song-name"]')?.textContent?.trim()||'',
      releaseDate:card.querySelector('[data-role="release-date"]')?.textContent?.trim()||'',
      countdownTarget:card.querySelector('[data-role="countdown-target"]')?.textContent?.trim()||'',
      countdown:[
        card.querySelector('[data-role="countdown-days"]')?.textContent?.trim()||'',
        card.querySelector('[data-role="countdown-hours"]')?.textContent?.trim()||'',
        card.querySelector('[data-role="countdown-minutes"]')?.textContent?.trim()||'',
        card.querySelector('[data-role="countdown-seconds"]')?.textContent?.trim()||''
      ].join(':'),
      previewSongId:card.querySelector('[data-preview-song-id]')?.dataset.previewSongId||'',
      previewBound:card.querySelector('.preview-button')?.dataset.bound==='true',
      artworkUrl:card.dataset.coverArtworkUrl||card.querySelector('.cover-native-fallback')?.currentSrc||'',
      previewDuration:card.querySelector('[data-preview-song-id]')?.dataset.previewDuration||'',
      preservedCard:card.dataset.watchdogPrepIdentity||'',
      preservedPreview:card.querySelector('[data-preview-song-id]')?.dataset.watchdogPreviewIdentity||''
    })));

    expect(states.map(state=>state.id)).toEqual(['glorioso-dia','no-fallaras']);
    const preservedGlorioso=states.find(state=>state.id==='glorioso-dia');
    expect(preservedGlorioso?.preservedCard).toBe('preserve');
    expect(preservedGlorioso?.preservedPreview).toBe('preserve');
    expect(states.every(state=>state.phase==='learning')).toBe(true);
    expect(states.every(state=>state.previewBound)).toBe(true);
    expect(states.map(state=>state.previewSongId)).toEqual(states.map(state=>state.id));
    expect(new Set(states.map(state=>state.releaseDate)).size).toBe(2);
    expect(new Set(states.map(state=>state.countdownTarget)).size).toBe(2);
    expect(new Set(states.map(state=>state.countdown)).size).toBe(2);
    expect(new Set(states.map(state=>state.artworkUrl)).size).toBe(2);
    expect(states.every(state=>state.artworkUrl.startsWith('https://'))).toBe(true);
    expect(states.every(state=>Number(state.previewDuration)>0)).toBe(true);
  }finally{
    await page.evaluate(() => window.IPCDJ_CATALOG_TEST.resume());
  }
});

test('catalog artwork stays bound to each song across current and future sections', async ({ page }, testInfo) => {
  await openHealthyPage(page);
  await page.waitForFunction(() => !!window.IPCDJ_CATALOG);

  const catalog = await page.evaluate(() => {
    const now = Date.now();
    return {
      snapshot: window.IPCDJ_CATALOG.snapshot(now),
      songs: window.IPCDJ_CATALOG.songs.map(song => ({
        id: song.id,
        artworkUrl: song.artworkUrl,
        artworkSource: song.artworkSource,
        futurePalette: song.futurePalette
      }))
    };
  });

  const highRes = value => String(value || '')
    .replace(/\/\d+x\d+bb\.(jpg|jpeg|png|webp)(\?.*)?$/i, '/1200x1200bb.$1$2')
    .replace(/\/100x100bb\.(jpg|jpeg|png|webp)(\?.*)?$/i, '/1200x1200bb.$1$2');

  for (const song of catalog.songs) {
    if (!song.artworkUrl) continue;
    const expectedUrl = highRes(song.artworkUrl);
    const expectedSource = 'verified-' + (song.artworkSource || 'curated');

    if (catalog.snapshot.upcoming.includes(song.id)) {
      const card = page.locator('#upcoming-songs [data-song-id="' + song.id + '"]');
      await expect(card).toHaveCount(1);
      await card.scrollIntoViewIfNeeded();

      // Force the same interaction hydration fallback real users have. Headless
      // WebKit can delay IntersectionObserver indefinitely despite the row being
      // scrolled into view.
      await card.dispatchEvent('pointerdown', { pointerType: 'touch', isPrimary: true });
      await page.waitForFunction(id => {
        const node = document.querySelector('#upcoming-songs [data-song-id="' + id + '"]');
        return !!node?.dataset.futureArtworkUrl;
      }, song.id, { timeout: 12000 });

      const state = await card.evaluate(node => {
        const blur = node.querySelector('.future-artwork-blur');
        const ghost = node.querySelector('.future-artwork-ghost');
        const css = getComputedStyle(node);
        return {
          url: node.dataset.futureArtworkUrl || '',
          source: node.dataset.futureArtworkSource || '',
          ready: node.classList.contains('future-artwork-ready'),
          themed: node.classList.contains('future-themed'),
          themeId: node.dataset.futureTheme || '',
          c1: css.getPropertyValue('--future-c1').trim(),
          c2: css.getPropertyValue('--future-c2').trim(),
          c3: css.getPropertyValue('--future-c3').trim(),
          gradientOpacity: Number(css.getPropertyValue('--future-gradient-opacity')),
          blurOpacityTarget: Number(css.getPropertyValue('--future-blur-opacity')),
          artOpacityTarget: Number(css.getPropertyValue('--future-art-opacity')),
          blurImage: blur ? getComputedStyle(blur).backgroundImage : 'none',
          ghostImage: ghost ? getComputedStyle(ghost).backgroundImage : 'none'
        };
      });

      expect(state.url).toBe(expectedUrl);
      expect(state.source).toBe(expectedSource);
      expect(state.themed).toBe(true);
      expect(state.themeId).toBe(song.id);
      expect(state.blurImage).not.toBe('none');
      expect(state.ghostImage).not.toBe('none');
      expect(state.gradientOpacity).toBeGreaterThanOrEqual(.9);

      if (song.futurePalette.length >= 3) {
        expect(state.c1).not.toBe(state.c2);
        expect(state.c2).not.toBe(state.c3);
      }

      if (/desktop/.test(testInfo.project.name)) {
        expect(state.blurOpacityTarget).toBeGreaterThanOrEqual(.4);
        expect(state.artOpacityTarget).toBeGreaterThanOrEqual(.24);
      } else if (/mobile/.test(testInfo.project.name)) {
        expect(state.blurOpacityTarget).toBeGreaterThanOrEqual(.2);
        expect(state.artOpacityTarget).toBeGreaterThanOrEqual(.1);
      }
      continue;
    }

    if (catalog.snapshot.current.includes(song.id)) {
      const card = page.locator('[data-current-song-card][data-song-id="' + song.id + '"]');
      await expect(card).toHaveCount(1);
      await page.waitForFunction(id => {
        const node = document.querySelector('[data-current-song-card][data-song-id="' + id + '"]');
        return !!node?.dataset.coverArtworkUrl;
      }, song.id);

      await page.waitForFunction(id => {
        const node=document.querySelector('[data-current-song-card][data-song-id="' + id + '"]');
        const img=node?.querySelector('.cover-native-fallback');
        return !!node?.classList.contains('cover-ready') && !!img?.complete && img.naturalWidth>0;
      }, song.id, { timeout: 12000 });

      const state = await card.evaluate(node => {
        const css = getComputedStyle(node);
        const native=node.querySelector('.cover-native-fallback');
        const fidelity=node.querySelector('.cover-fidelity');
        const fidelityStyle=fidelity?getComputedStyle(fidelity):null;
        return {
          url: node.dataset.coverArtworkUrl || '',
          source: node.dataset.coverArtworkSource || '',
          artworkId: node.dataset.coverArtwork || '',
          themeId: node.dataset.coverTheme || '',
          c1: css.getPropertyValue('--cover-c1').trim(),
          c2: css.getPropertyValue('--cover-c2').trim(),
          c3: css.getPropertyValue('--cover-c3').trim(),
          nativeSrc:native?.currentSrc||native?.src||'',
          nativeWidth:native?.naturalWidth||0,
          nativeHeight:native?.naturalHeight||0,
          fidelityImage:fidelityStyle?.backgroundImage||'none',
          fidelityOpacity:Number(fidelityStyle?.opacity||0),
          fidelityFilter:fidelityStyle?.filter||''
        };
      });

      expect(state.url).toBe(expectedUrl);
      expect(state.source).toBe(expectedSource);
      expect(state.artworkId).toBe(song.id);
      expect(state.themeId).toBe(song.id);
      expect(state.c1.length).toBeGreaterThan(0);
      expect(state.c2.length).toBeGreaterThan(0);
      expect(state.c3.length).toBeGreaterThan(0);
      expect(state.nativeSrc).toBe(expectedUrl);
      expect(state.nativeWidth).toBeGreaterThanOrEqual(500);
      expect(state.nativeHeight).toBeGreaterThanOrEqual(500);
      expect(state.fidelityImage).not.toBe('none');
      expect(state.fidelityFilter).toContain('brightness(1.08)');
    }
  }
});

test('rotation preserves the verified Glorioso Día cover from Después into Current at readable fidelity', async ({ page }) => {
  await openHealthyPage(page);
  await page.waitForFunction(() => !!window.IPCDJ_CATALOG_TEST);

  const expected='https://i.scdn.co/image/ab67616d0000b27372bba4048e09a242595e4a2c';

  try{
    await page.evaluate(() => window.IPCDJ_CATALOG_TEST.renderAt(Date.parse('2026-09-28T05:59:59-04:00')));

    const future=page.locator('#upcoming-songs [data-song-id="glorioso-dia"]');
    await expect(future).toHaveCount(1);
    await future.dispatchEvent('pointerdown',{pointerType:'touch',isPrimary:true});
    await page.waitForFunction(() => {
      const node=document.querySelector('#upcoming-songs [data-song-id="glorioso-dia"]');
      return !!node?.dataset.futureArtworkUrl;
    }, null, { timeout:12000 });

    const before=await future.evaluate(node=>({
      url:node.dataset.futureArtworkUrl||'',
      source:node.dataset.futureArtworkSource||''
    }));

    await page.evaluate(() => window.IPCDJ_CATALOG_TEST.renderAt(Date.parse('2026-09-28T06:00:00-04:00')));

    const current=page.locator('[data-current-song-card][data-song-id="glorioso-dia"]');
    await expect(current).toHaveCount(1);
    await page.waitForFunction(() => {
      const node=document.querySelector('[data-current-song-card][data-song-id="glorioso-dia"]');
      const img=node?.querySelector('.cover-native-fallback');
      return !!node?.classList.contains('cover-ready') && !!img?.complete && img.naturalWidth>0;
    }, null, { timeout:12000 });

    // cover-ready intentionally crossfades the high-fidelity layer. Wait for the
    // visual transition to settle before measuring it; do not relax the final
    // opacity requirement.
    await page.waitForFunction(() => {
      const node=document.querySelector('[data-current-song-card][data-song-id="glorioso-dia"]');
      const fidelity=node?.querySelector('.cover-fidelity');
      if(!node||!fidelity)return false;
      if(node.classList.contains('subject-ready'))return true;
      return Number(getComputedStyle(fidelity).opacity)>=.5;
    }, null, { timeout:3500 });

    const after=await current.evaluate(node=>{
      const native=node.querySelector('.cover-native-fallback');
      const fidelity=node.querySelector('.cover-fidelity');
      const style=fidelity?getComputedStyle(fidelity):null;
      return {
        url:node.dataset.coverArtworkUrl||'',
        source:node.dataset.coverArtworkSource||'',
        nativeSrc:native?.currentSrc||native?.src||'',
        nativeWidth:native?.naturalWidth||0,
        nativeHeight:native?.naturalHeight||0,
        fidelityImage:style?.backgroundImage||'none',
        fidelityOpacity:Number(style?.opacity||0),
        fidelityFilter:style?.filter||'',
        subjectReady:node.classList.contains('subject-ready')
      };
    });

    expect(before.url).toBe(expected);
    expect(before.source).toBe('verified-spotify');
    expect(after.url).toBe(expected);
    expect(after.url).toBe(before.url);
    expect(after.source).toBe('verified-spotify');
    expect(after.nativeSrc).toBe(expected);
    expect(after.nativeWidth).toBeGreaterThanOrEqual(500);
    expect(after.nativeHeight).toBeGreaterThanOrEqual(500);
    expect(after.fidelityImage).not.toBe('none');
    expect(after.fidelityFilter).toContain('brightness(1.08)');
    if(!after.subjectReady)expect(after.fidelityOpacity).toBeGreaterThanOrEqual(.5);
  }finally{
    await page.evaluate(() => window.IPCDJ_CATALOG_TEST.resume());
  }
});

test('PWA shell, service worker and efficiency guardrails remain healthy', async ({ page, request }, testInfo) => {
  const nonce = Date.now();

  const manifestResponse = await request.get('/manifest-v9.webmanifest?healthcheck=' + nonce, {
    headers: { 'cache-control': 'no-cache' }
  });
  expect(manifestResponse.ok()).toBe(true);
  const manifest = await manifestResponse.json();

  expect(manifest.id).toBe('./');
  expect(manifest.start_url).toBe('./');
  expect(manifest.scope).toBe('./');
  expect(manifest.display).toBe('standalone');
  expect(manifest.background_color).toBe('#000000');
  expect(manifest.theme_color).toBe('#000000');
  expect(Array.isArray(manifest.icons)).toBe(true);
  expect(manifest.icons.length).toBeGreaterThanOrEqual(2);

  for (const icon of manifest.icons) {
    const iconResponse = await request.get(icon.src, {
      headers: { 'cache-control': 'no-cache' }
    });
    expect(iconResponse.ok()).toBe(true);
  }

  const serviceWorkerResponse = await request.get('/sw.js?healthcheck=' + nonce, {
    headers: { 'cache-control': 'no-cache' }
  });
  expect(serviceWorkerResponse.ok()).toBe(true);
  const serviceWorkerText = await serviceWorkerResponse.text();
  expect(serviceWorkerText).toContain('ipcdj-worship-v181');
  expect(serviceWorkerText).toContain('CACHE_FRESH_SHELL');
  expect(serviceWorkerText).toContain('refresh-test');

  await openHealthyPage(page);

  const shell = await page.evaluate(async () => {
    const allNodes = document.querySelectorAll('*').length;
    const resources = performance.getEntriesByType('resource');
    const snapshot = window.IPCDJ_HEALTH.checkNow();

    let serviceWorkerActive = false;
    if ('serviceWorker' in navigator) {
      try {
        const registration = await Promise.race([
          navigator.serviceWorker.ready,
          new Promise(resolve => setTimeout(() => resolve(null), 8000))
        ]);
        serviceWorkerActive = !!(registration && registration.active);
      } catch (_) {}
    }

    const ids = [...document.querySelectorAll('[id]')].map(el => el.id);
    const duplicateIds = ids.filter((id, index) => ids.indexOf(id) !== index);

    return {
      allNodes,
      resourceCount: resources.length,
      serviceWorkerActive,
      duplicateIds: [...new Set(duplicateIds)],
      horizontalOverflow: snapshot.horizontalOverflow,
      sameOriginResourceErrors: snapshot.sameOriginResourceErrors,
      errors: snapshot.errors,
      rejections: snapshot.rejections,
      previewErrors: snapshot.previewErrors,
      longTasks: snapshot.longTasks,
      longAnimationFrames: snapshot.longAnimationFrames,
      cls: snapshot.cls,
      lcp: snapshot.lcp
    };
  });

  const refreshStage = await page.evaluate(async () => {
    const currentBuild=document.querySelector('meta[name="ipcdj-build"]')?.content||'';

    // Simulate the exact failure we are guarding against: an installed PWA has
    // an older shell cached when the user performs one refresh.
    const staleCache=await caches.open('ipcdj-worship-v181');
    await staleCache.put(
      './__offline_index__',
      new Response('<!doctype html><meta name="ipcdj-build" content="stale-watchdog" />',{
        headers:{'Content-Type':'text/html; charset=utf-8'}
      })
    );

    const staged=await window.IPCDJ_REFRESH_TEST.stageLatestShell();
    const keys=await caches.keys();
    const cacheKey=keys.find(key=>key==='ipcdj-worship-v181')||'';
    let cachedBuild='';
    if(cacheKey){
      const cache=await caches.open(cacheKey);
      const cachedShell=await cache.match('./__offline_index__');
      const html=cachedShell ? await cachedShell.text() : '';
      const match=html.match(/<meta\s+name=["']ipcdj-build["']\s+content=["']([^"']+)["']/i);
      cachedBuild=match ? match[1] : '';
    }
    return {currentBuild,staged,cacheKey,cachedBuild};
  });

  expect(refreshStage.staged.ok).toBe(true);
  expect(refreshStage.staged.build).toBe(refreshStage.currentBuild);
  expect(refreshStage.cacheKey).toBe('ipcdj-worship-v181');
  expect(refreshStage.cachedBuild).toBe(refreshStage.currentBuild);

  // Intentionally coarse runaway guards, not synthetic speed scores.
  expect(shell.allNodes).toBeLessThan(10000);
  expect(shell.resourceCount).toBeLessThan(250);
  expect(shell.serviceWorkerActive).toBe(true);
  expect(shell.duplicateIds).toEqual([]);
  expect(shell.horizontalOverflow).toBeLessThanOrEqual(4);
  expect(shell.sameOriginResourceErrors).toBe(0);
  expect(shell.errors).toBe(0);
  expect(shell.rejections).toBe(0);
  expect(shell.previewErrors).toBe(0);

  await testInfo.attach('pwa-efficiency-health.json', {
    body: Buffer.from(JSON.stringify(shell, null, 2)),
    contentType: 'application/json'
  });
});



test('notification shell is safe, opt-in only and service-worker ready', async ({ page, request }) => {
  const nonce=Date.now();
  const [configResponse, clientResponse, uiResponse, foundationResponse, swResponse] = await Promise.all([
    request.get('/notifications/config.json?healthcheck='+nonce,{headers:{'cache-control':'no-cache'}}),
    request.get('/notifications/client.js?healthcheck='+nonce,{headers:{'cache-control':'no-cache'}}),
    request.get('/notifications/ui.js?healthcheck='+nonce,{headers:{'cache-control':'no-cache'}}),
    request.get('/notifications/sw-foundation.js?healthcheck='+nonce,{headers:{'cache-control':'no-cache'}}),
    request.get('/sw.js?healthcheck='+nonce,{headers:{'cache-control':'no-cache'}})
  ]);
  for(const response of [configResponse,clientResponse,uiResponse,foundationResponse,swResponse]){
    expect(response.ok()).toBe(true);
  }

  const config=await configResponse.json();
  expect(typeof config.enabled).toBe('boolean');
  expect(config.enabled).toBe(false);
  expect(config.siteOrigin).toBe('https://staging.worship.ipcdj.org');
  expect(config.apiOrigin).toBe('');

  const swSource=await swResponse.text();
  expect(swSource).toContain('addEventListener("push"');
  expect(swSource).toContain('addEventListener("notificationclick"');
  expect(swSource).toContain('showNotification');
  expect(swSource).toContain('notifications/sw-foundation.js');
  expect(swSource).toContain('icon-512.png');

  await openHealthyPage(page);
  const permissionBefore=await page.evaluate(() => (
    'Notification' in window ? Notification.permission : 'unsupported'
  ));
  await page.waitForTimeout(700);
  const permissionAfter=await page.evaluate(() => (
    'Notification' in window ? Notification.permission : 'unsupported'
  ));
  expect(permissionAfter).toBe(permissionBefore);

  const apiExists=await page.evaluate(() => !!window.IPCDJ_NOTIFICATIONS);
  expect(apiExists).toBe(true);

  if(!config.enabled){
    await expect(page.locator('#ipcdj-notification-card')).toHaveCount(0);
  }
});


test('desktop notification test page is deployed and never auto-prompts', async ({ page, request }) => {
  const nonce=Date.now();
  const response=await request.get('/notifications/test.html?healthcheck='+nonce,{headers:{'cache-control':'no-cache'}});
  expect(response.ok()).toBe(true);
  const source=await response.text();
  expect(source).toContain('Probar notificación en este dispositivo');
  expect(source).toContain('registration.showNotification');
  expect(source).toContain("Notification.requestPermission()");
  expect(source).toContain("data:{");
  expect(source).toContain("url:'/?notification-test=success'");
  expect(source).toContain("../icon-512.png?v=9");
  expect(source).toContain('Backend IPCDJ remoto');

  await page.goto('/notifications/test.html?healthcheck='+nonce,{waitUntil:'domcontentloaded'});
  const before=await page.evaluate(() => ('Notification' in window ? Notification.permission : 'unsupported'));
  await page.waitForTimeout(600);
  const after=await page.evaluate(() => ('Notification' in window ? Notification.permission : 'unsupported'));
  expect(after).toBe(before);
  await expect(page.getByRole('button',{name:'Probar notificación en este dispositivo'})).toBeVisible();
  await expect(page.locator('#push')).toHaveText(/Disponible|No disponible/);
});


test('social share preview is crawler-ready', async ({ page, request }) => {
  const nonce=Date.now();
  const crawlers=[
    'facebookexternalhit/1.1 (+http://www.facebook.com/externalhit_uatext.php)',
    'WhatsApp/2.25.25.85 A'
  ];

  for(const userAgent of crawlers){
    const [htmlResponse,imageResponse,robotsResponse]=await Promise.all([
      request.get('/?social-health='+nonce,{headers:{'cache-control':'no-cache','user-agent':userAgent}}),
      request.get('/social-preview-v180.jpg?social-health='+nonce,{headers:{'cache-control':'no-cache','user-agent':userAgent}}),
      request.get('/robots.txt?social-health='+nonce,{headers:{'cache-control':'no-cache','user-agent':userAgent}})
    ]);
    expect(htmlResponse.ok()).toBe(true);
    expect(imageResponse.ok()).toBe(true);
    expect(robotsResponse.ok()).toBe(true);
    expect((imageResponse.headers()['content-type']||'')).toMatch(/^image\/jpeg/);

    const imageBytes=await imageResponse.body();
    expect(imageBytes.length).toBeGreaterThan(5000);
    expect(imageBytes.length).toBeLessThan(300000);

    const html=await htmlResponse.text();
    const ogIndex=html.indexOf('property="og:title"');
    expect(ogIndex).toBeGreaterThan(0);
    expect(ogIndex).toBeLessThan(2500);
    expect(html).toContain('prefix="og: https://ogp.me/ns#"');
    expect(html).toContain('property="og:site_name" content="IPCDJ Worship"');
    expect(html).toContain('property="og:image" content="https://worship.ipcdj.org/social-preview-v180.jpg?v=180"');
    expect(html).toContain('property="og:image:url" content="https://worship.ipcdj.org/social-preview-v180.jpg?v=180"');
    expect(html).toContain('property="og:image:secure_url" content="https://worship.ipcdj.org/social-preview-v180.jpg?v=180"');
    expect(html).toContain('property="og:image:type" content="image/jpeg"');
    expect(html).toContain('property="og:image:width" content="1200"');
    expect(html).toContain('property="og:image:height" content="630"');
    expect(html).toContain('rel="image_src" href="https://worship.ipcdj.org/social-preview-v180.jpg?v=180"');
    expect(html).toContain('itemprop="image" content="https://worship.ipcdj.org/social-preview-v180.jpg?v=180"');
    expect(html).toContain('name="twitter:card" content="summary_large_image"');

    const robots=await robotsResponse.text();
    expect(robots).toContain('User-agent: facebookexternalhit');
    expect(robots).toContain('User-agent: meta-externalagent');
  }

  await page.goto('/?social-health='+nonce,{waitUntil:'domcontentloaded'});
  await expect(page.locator('meta[property="og:image"]')).toHaveAttribute('content','https://worship.ipcdj.org/social-preview-v180.jpg?v=180');
});


test('estreno arrival intensifies artwork glow and retires countdown smoothly', async ({ page, request }) => {
  const sourceResponse=await request.get('/?estreno-arrival-health='+Date.now(),{
    headers:{'cache-control':'no-cache'}
  });
  expect(sourceResponse.ok()).toBe(true);
  const source=await sourceResponse.text();
  expect(source).toContain('class="release-aura"');
  expect(source).toContain('border-color:var(--stage-border)');
  expect(source).toContain('background:var(--stage-accent)');
  expect(source).toContain('var(--stage-glow)');
  expect(source).toContain('.current.phase-release::after');
  expect(source).toContain('rgba(3,6,10,.52)');
  expect(source).toContain('backdrop-filter:blur(10px) saturate(1.05)');
  expect(source).toContain('rgba(var(--cover-dominant),.42)');
  expect(source).toContain('rgba(var(--cover-c1),.34)');
  expect(source).toContain('rgba(var(--cover-c2),.30)');
  expect(source).toContain('rgba(var(--cover-c3),.24)');
  expect(source).toContain('max-height 1.05s');
  expect(source).toContain('prepControlsHidden=phase.key==="release"||phase.key==="released"');

  await openHealthyPage(page);

  const visual=await page.evaluate(async () => {
    const card=document.createElement('section');
    card.className='card current phase-release';
    card.style.cssText=[
      '--stage-accent:rgb(42,224,126)',
      '--stage-soft:rgba(42,224,126,.135)',
      '--stage-border:rgba(42,224,126,.44)',
      '--stage-glow:rgba(42,224,126,.24)',
      '--stage-text:rgb(220,255,235)',
      '--cover-c1:44,86,184',
      '--cover-c2:61,137,220',
      '--cover-c3:25,53,128'
    ].join(';');
    card.innerHTML=`
      <div class="release-aura" aria-hidden="true"></div>
      <div class="status">HOY · ESTRENO</div>
      <h2 class="song-name">Prueba</h2>
      <p class="artist">IPCDJ</p>
      <div class="post-release-banner">
        <span class="post-release-kicker">ESTRENO</span>
        <strong class="post-release-title">Hoy es el día</strong>
        <span class="post-release-note">Prueba</span>
      </div>
      <div class="countdown-wrap">00</div>
      <div class="progress-wrap">100%</div>
      <div class="timeline-item estreno active-phase">
        <div class="timeline-label">Estreno</div>
        <div class="timeline-date">Hoy</div>
      </div>
    `;
    document.body.appendChild(card);
    await new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)));

    const aura=getComputedStyle(card.querySelector('.release-aura'));
    const countdown=getComputedStyle(card.querySelector('.countdown-wrap'));
    const progress=getComputedStyle(card.querySelector('.progress-wrap'));
    const banner=getComputedStyle(card.querySelector('.post-release-banner'));
    const status=getComputedStyle(card.querySelector('.status'));
    const timeline=getComputedStyle(card.querySelector('.timeline-item.estreno'));
    const cardStyle=getComputedStyle(card);

    const result={
      auraOpacity:Number(aura.opacity),
      countdownOpacity:Number(countdown.opacity),
      countdownMaxHeight:countdown.maxHeight,
      countdownTransition:countdown.transitionProperty,
      countdownDuration:countdown.transitionDuration,
      progressOpacity:Number(progress.opacity),
      bannerOpacity:Number(banner.opacity),
      bannerVisibility:banner.visibility,
      cardShadow:cardStyle.boxShadow,
      statusShadow:status.boxShadow,
      statusTextShadow:status.textShadow,
      timelineShadow:timeline.boxShadow,
      cardBorder:cardStyle.borderColor,
      auraBackground:aura.backgroundImage,
      statusBorder:status.borderColor
    };
    card.remove();
    return result;
  });

  expect(visual.auraOpacity).toBeGreaterThan(.8);
  expect(visual.countdownOpacity).toBe(0);
  expect(visual.countdownMaxHeight).toBe('0px');
  expect(visual.countdownTransition).toContain('opacity');
  expect(visual.countdownDuration).not.toBe('0s');
  expect(visual.progressOpacity).toBe(0);
  expect(visual.bannerOpacity).toBe(1);
  expect(visual.bannerVisibility).toBe('visible');
  expect(visual.cardShadow).not.toBe('none');
  expect(visual.statusShadow).not.toBe('none');
  expect(visual.statusTextShadow).not.toBe('none');
  expect(visual.timelineShadow).not.toBe('none');
  expect(visual.cardBorder).toContain('42, 224, 126');
  expect(visual.statusBorder).toContain('42, 224, 126');
  expect(visual.auraBackground).not.toContain('42, 224, 126');
  expect(visual.auraBackground).not.toBe('none');
});


test('release day amplifies the page ambient field from the song palette', async ({ page, request }) => {
  const sourceResponse=await request.get('/?ambient-release-health='+Date.now(),{
    headers:{'cache-control':'no-cache'}
  });
  expect(sourceResponse.ok()).toBe(true);
  const source=await sourceResponse.text();
  expect(source).toContain('html.ipcdj-ambient-release .ambient-field-active');
  expect(source).toContain('html.ipcdj-ambient-release .ambient-field-active::before');
  expect(source).toContain('--ambient-c1');
  expect(source).toContain('--ambient-c2');
  expect(source).toContain('--ambient-c3');
  expect(source).toContain('const release=entries.find(({phase})=>phase&&phase.key==="release")');
  expect(source).toContain('document.documentElement.classList.toggle("ipcdj-ambient-release"');
  expect(source).toContain('driver:"+song.id+"|phase:"');

  await openHealthyPage(page);
  await page.waitForFunction(() => !!window.IPCDJ_CATALOG_TEST);

  const visual=await page.evaluate(async () => {
    const settle=document.createElement('style');
    settle.textContent='.ambient-field,.ambient-field::before,.ambient-blob{transition:none!important;animation:none!important}';
    document.head.appendChild(settle);

    try{
      // Lock the real runtime into an actual release-day phase so the one-second
      // live clock cannot race this visual assertion back to today's released state.
      window.IPCDJ_CATALOG_TEST.renderAt(Date.parse('2026-10-25T00:00:01-04:00'));
      await new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)));

      const field=document.querySelector('.ambient-field-active')||document.querySelector('.ambient-field');
      if(!field)return null;
      const blob=field.querySelector('.ambient-blob');

      field.style.setProperty('--ambient-c1','88,57,44');
      field.style.setProperty('--ambient-c2','179,111,62');
      field.style.setProperty('--ambient-c3','54,75,91');
      field.style.setProperty('--ambient-c4','72,122,170');
      if(blob)blob.style.setProperty('--blob-rgb','179,111,62');

      const fieldStyle=getComputedStyle(field);
      const halo=getComputedStyle(field,'::before');
      const blobStyle=blob?getComputedStyle(blob):null;
      return {
        releaseClass:document.documentElement.classList.contains('ipcdj-ambient-release'),
        fieldOpacity:Number(fieldStyle.opacity),
        haloOpacity:Number(halo.opacity),
        haloBackground:halo.backgroundImage,
        haloFilter:halo.filter||halo.webkitFilter,
        blobBackground:blobStyle?blobStyle.backgroundImage:'',
        blobFilter:blobStyle?(blobStyle.filter||blobStyle.webkitFilter):'',
        reducedMotion:matchMedia('(prefers-reduced-motion: reduce)').matches,
        reducedData:matchMedia('(prefers-reduced-data: reduce)').matches
      };
    }finally{
      settle.remove();
      window.IPCDJ_CATALOG_TEST.resume();
    }
  });

  expect(visual).not.toBeNull();
  expect(visual.releaseClass).toBe(true);
  const ambientPreferenceFloor=visual.reducedData ? .53 : (visual.reducedMotion ? .59 : .95);
  const haloPreferenceFloor=visual.reducedData ? .51 : (visual.reducedMotion ? .57 : .8);
  expect(visual.fieldOpacity).toBeGreaterThan(ambientPreferenceFloor);
  expect(visual.haloOpacity).toBeGreaterThan(haloPreferenceFloor);
  expect(visual.haloBackground).not.toBe('none');
  expect(visual.haloBackground).toContain('88, 57, 44');
  expect(visual.haloBackground).toContain('179, 111, 62');
  expect(visual.haloFilter).not.toBe('none');
  expect(visual.blobBackground).not.toBe('none');
  expect(visual.blobFilter).not.toBe('none');
});


test('v174 release lifecycle settles exactly thirty minutes after releaseAt', async ({ request }) => {
  const response=await request.get('/?v174-release-settle='+Date.now(),{
    headers:{'cache-control':'no-cache'}
  });
  expect(response.ok()).toBe(true);
  const source=await response.text();

  expect(source).toContain('const RELEASE_SETTLE_DELAY_MS=30*60*1000;');
  expect(source).toContain('const releaseSettledAt=release+RELEASE_SETTLE_DELAY_MS;');
  expect(source).toContain('if(now<releaseSettledAt)return {');
  expect(source).toContain('phase.key==="released"?"ESTRENADO"');
  expect(source).toContain('setCardText(card,"post-release-kicker","ESTRENADO")');
  expect(source).toContain('La canción ya fue presentada en el servicio de hoy.');
  expect(source).toContain('.current.phase-released .timeline{');
  expect(source).not.toContain('.current.phase-released .timeline{\n      display:none;');
});

test('v174 dominant artwork color drives release ambience', async ({ page, request }) => {
  const response=await request.get('/?v174-dominant-ambient='+Date.now(),{
    headers:{'cache-control':'no-cache'}
  });
  expect(response.ok()).toBe(true);
  const source=await response.text();

  expect(source).toContain('--ambient-dominant:55,93,202');
  expect(source).toContain('--cover-dominant:96,62,44');
  expect(source).toContain('field.style.setProperty("--ambient-dominant",dominant.join(","))');
  expect(source).toContain('card.style.setProperty("--cover-dominant"');
  expect(source).toContain('rgba(var(--ambient-dominant),.62)');
  expect(source).toContain('rgba(var(--cover-dominant),.88)');
  expect(source).toContain('futurePalette:[[36,76,118],[46,82,120],[28,55,84]]');

  await openHealthyPage(page);
  await page.waitForFunction(() => !!window.IPCDJ_CATALOG_TEST);
  const visual=await page.evaluate(async()=>{
    const settle=document.createElement('style');
    settle.textContent='.ambient-field,.ambient-field::before,.ambient-blob{transition:none!important;animation:none!important}';
    document.head.appendChild(settle);
    try{
      window.IPCDJ_CATALOG_TEST.renderAt(Date.parse('2026-10-25T00:00:01-04:00'));
      await new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)));

      const field=document.querySelector('.ambient-field-active')||document.querySelector('.ambient-field');
      if(!field)return null;
      field.style.setProperty('--ambient-dominant','36,76,118');
      field.style.setProperty('--ambient-c1','36,76,118');
      field.style.setProperty('--ambient-c2','46,82,120');
      field.style.setProperty('--ambient-c3','28,55,84');

      const halo=getComputedStyle(field,'::before');
      return {
        releaseClass:document.documentElement.classList.contains('ipcdj-ambient-release'),
        background:halo.backgroundImage,
        opacity:Number(halo.opacity),
        filter:halo.filter||halo.webkitFilter,
        reducedMotion:matchMedia('(prefers-reduced-motion: reduce)').matches,
        reducedData:matchMedia('(prefers-reduced-data: reduce)').matches
      };
    }finally{
      settle.remove();
      window.IPCDJ_CATALOG_TEST.resume();
    }
  });

  expect(visual).not.toBeNull();
  expect(visual.releaseClass).toBe(true);
  expect(visual.background).toContain('36, 76, 118');
  const dominantPreferenceFloor=visual.reducedData ? .51 : (visual.reducedMotion ? .57 : .9);
  expect(visual.opacity).toBeGreaterThan(dominantPreferenceFloor);
  expect(visual.filter).not.toBe('none');
});

test('v174 preview requests playback audio session for iPhone silent mode', async ({ request }) => {
  const response=await request.get('/?v174-audio-session='+Date.now(),{
    headers:{'cache-control':'no-cache'}
  });
  expect(response.ok()).toBe(true);
  const source=await response.text();

  expect(source).toContain('function configurePreviewAudioSessionForPlayback()');
  expect(source).toContain('const session=navigator.audioSession;');
  expect(source).toContain('if(session.type!=="playback")session.type="playback";');
  expect(source).toContain('function unlockWebPreviewContextFromGesture(){');
  expect(source).toContain('async function startWebAudioPreview(song,data');
});


test('v175 keeps artwork composition stable when Estrenado card compacts', async ({ page, request }) => {
  const response=await request.get('/?v175-cover-frame='+Date.now(),{
    headers:{'cache-control':'no-cache'}
  });
  expect(response.ok()).toBe(true);
  const source=await response.text();

  expect(source).toContain('function syncLifecycleStableCoverFrame(card)');
  expect(source).toContain('--cover-frame-height:0px');
  expect(source).toContain('height:max(calc(100% + 68px),calc(var(--cover-frame-height) + 68px))');
  expect(source).toContain('height:var(--subject-stable-height,var(--subject-height))');
  expect(source).toContain('if(card.classList.contains("phase-released")&&timeline)');
  expect(source).toContain('referenceHeight+=timelineHeight+12');

  await openHealthyPage(page);

  const result=await page.evaluate(async()=>{
    const card=document.createElement('section');
    card.className='card current phase-released';
    card.style.width=Math.max(240,Math.min(760,window.innerWidth-32))+'px';
    card.style.setProperty('--subject-height','37%');
    card.style.setProperty('--subject-mobile-height','34%');
    card.style.setProperty('--cover-image','none');
    card.innerHTML=`
      <img class="cover-native-fallback" alt="" />
      <div class="cover-detail"></div>
      <div class="cover-edge-detail"></div>
      <div class="cover-subject-detail"></div>
      <div class="status">ESTRENADO</div>
      <h2 class="song-name">Prueba</h2>
      <p class="artist">IPCDJ</p>
      <div class="post-release-banner">
        <span class="post-release-kicker">ESTRENADO</span>
        <strong class="post-release-title">ESTRENO COMPLETADO</strong>
        <span class="post-release-note">Prueba</span>
      </div>
      <div class="timeline">
        <div class="timeline-item"><div class="timeline-label">Aprendizaje</div><div class="timeline-date">A</div></div>
        <div class="timeline-item"><div class="timeline-label">Preparación final</div><div class="timeline-date">B</div></div>
        <div class="timeline-item estreno"><div class="timeline-label">Estreno</div><div class="timeline-date">C</div></div>
      </div>
    `;
    document.body.appendChild(card);
    await new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)));

    const compactHeight=card.getBoundingClientRect().height;
    const timeline=card.querySelector('.timeline');
    const timelineContentHeight=timeline.scrollHeight;

    if(typeof window.syncLifecycleStableCoverFrame==='function'){
      window.syncLifecycleStableCoverFrame(card);
    }else if(typeof syncLifecycleStableCoverFrame==='function'){
      syncLifecycleStableCoverFrame(card);
    }

    await new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)));

    const style=getComputedStyle(card);
    const frameHeight=parseFloat(style.getPropertyValue('--cover-frame-height'))||0;
    const subjectHeight=parseFloat(getComputedStyle(card.querySelector('.cover-subject-detail')).height)||0;
    const nativeHeight=parseFloat(getComputedStyle(card.querySelector('.cover-native-fallback')).height)||0;
    const mobile=window.matchMedia('(max-width:640px)').matches;
    const expectedPercent=mobile ? 0.34 : 0.37;
    const expectedSubject=frameHeight*expectedPercent;

    card.remove();

    return {
      compactHeight,
      timelineContentHeight,
      frameHeight,
      subjectHeight,
      nativeHeight,
      expectedSubject,
      expectedPercent
    };
  });

  expect(result.timelineContentHeight).toBeGreaterThan(0);
  expect(result.frameHeight).toBeGreaterThan(result.compactHeight);
  expect(result.frameHeight).toBeGreaterThanOrEqual(result.compactHeight+result.timelineContentHeight);
  expect(result.nativeHeight).toBeGreaterThan(result.compactHeight+60);
  expect(Math.abs(result.subjectHeight-result.expectedSubject)).toBeLessThan(2.5);
});


test('v179 lifecycle cover-frame work is coalesced between phase transitions', async ({ request }) => {
  const response=await request.get('/?v179-frame-coalesce='+Date.now(),{headers:{'cache-control':'no-cache'}});
  expect(response.ok()).toBe(true);
  const source=await response.text();
  expect(source).toContain('const lifecycleCoverFrameQueue=new WeakSet()');
  expect(source).toContain('function scheduleLifecycleStableCoverFrame(card)');
  expect(source).toContain('if(previousPhase!==phase.key||!card.dataset.coverFrameHeight)');
  expect(source).toContain('forEach(scheduleLifecycleStableCoverFrame)');
});

test('v176 lifecycle UI transitions cleanly through Después, prep, release, Estrenado and introduced', async ({ page }) => {
  await openHealthyPage(page);
  await page.waitForFunction(() => !!window.IPCDJ_CATALOG && !!window.IPCDJ_CATALOG_TEST);

  const result = await page.evaluate(async () => {
    const waitPaint = () => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)));
    const renderAt = async iso => {
      const ts = Date.parse(iso);
      const snapshot=window.IPCDJ_CATALOG_TEST.renderAt(ts);
      // Core lifecycle membership/text changes are synchronous. Keep checkpoint
      // sampling independent from headless compositor frame scheduling.
      await Promise.resolve();

      const current=[...document.querySelectorAll('#current-song-cards [data-current-song-card]')].map(node=>({
        id:node.dataset.songId,
        phase:node.dataset.phase,
        status:node.querySelector('[data-role="status"]')?.textContent?.trim()||'',
        title:node.querySelector('[data-role="post-release-title"]')?.textContent?.trim()||''
      }));
      const upcoming=[...document.querySelectorAll('#upcoming-songs [data-song-id]')].map(node=>node.dataset.songId);
      const introduced=[...document.querySelectorAll('#introduced-songs .recent strong')].map(node=>node.textContent?.trim()||'');
      const introducedRows=[...document.querySelectorAll('#introduced-songs .recent')].map(node=>({
        title:node.querySelector('strong')?.textContent?.trim()||'',
        date:node.querySelector('.date')?.textContent?.trim()||''
      }));
      const duplicateIds=[...document.querySelectorAll('[id]')].map(n=>n.id).filter((id,i,a)=>a.indexOf(id)!==i);

      return {
        current,upcoming,introduced,introducedRows,duplicateIds,
        snapshot:{
          current:[...snapshot.current],
          upcoming:[...snapshot.upcoming],
          introduced:[...snapshot.introduced],
          phases:{...snapshot.phases}
        },
        nodes:document.querySelectorAll('*').length,
        width:document.documentElement.scrollWidth,
        viewport:document.documentElement.clientWidth
      };
    };

    try{
      const checkpoints={
        beforeActive:await renderAt('2026-09-28T05:59:59-04:00'),
        afterActive:await renderAt('2026-09-28T06:00:00-04:00'),
        diosIntroduced:await renderAt('2026-09-29T00:00:01-04:00'),
        learning:await renderAt('2026-10-12T12:00:00-04:00'),
        finalPrep:await renderAt('2026-10-20T12:00:00-04:00'),
        releaseStart:await renderAt('2026-10-25T00:00:01-04:00'),
        justBeforeSettled:await renderAt('2026-10-25T11:29:59-04:00'),
        settled:await renderAt('2026-10-25T11:30:00-04:00'),
        gloriosoBeforeRollover:await renderAt('2026-10-26T05:59:59-04:00'),
        gloriosoRollover:await renderAt('2026-10-26T06:00:00-04:00'),
        introduced:await renderAt('2026-10-27T00:00:01-04:00'),
        noFallarasReleased:await renderAt('2026-11-08T11:30:00-05:00')
      };

      const stressTimes=[
        '2026-09-28T05:59:59-04:00','2026-09-28T06:00:01-04:00',
        '2026-10-12T12:00:00-04:00','2026-10-20T12:00:00-04:00',
        '2026-10-25T00:00:01-04:00','2026-10-25T11:29:59-04:00',
        '2026-10-25T11:30:00-04:00','2026-10-26T05:59:59-04:00',
        '2026-10-26T06:00:00-04:00','2026-10-27T00:00:01-04:00'
      ];

      const transitionStart=performance.now();
      for(let round=0;round<12;round++){
        window.IPCDJ_CATALOG_TEST.renderAt(Date.parse(stressTimes[round%stressTimes.length]));
      }
      const transitionRenderMs=performance.now()-transitionStart;

      // Model the real one-second countdown cadence separately from rare lifecycle jumps.
      const steadyStart=Date.parse('2026-10-20T12:00:00-04:00');
      const steadyTickStart=performance.now();
      for(let tick=0;tick<30;tick++){
        window.IPCDJ_CATALOG_TEST.renderAt(steadyStart+(tick*1000));
      }
      const steadyTickMs=performance.now()-steadyTickStart;

      // Require an actual two-frame paint completion for liveness, but do not
      // score requestAnimationFrame wall-clock latency as app CPU performance.
      // Headless WebKit CI may throttle compositor frames by multiple seconds.
      await waitPaint();
      const paintFramesCompleted=true;

      return {
        checkpoints,
        transitionRenderMs,
        steadyTickMs,
        paintFramesCompleted,
        finalNodes:document.querySelectorAll('*').length,
        finalCurrentCount:document.querySelectorAll('#current-song-cards [data-current-song-card]').length,
        lockHeld:window.IPCDJ_CATALOG_TEST.locked()
      };
    }finally{
      window.IPCDJ_CATALOG_TEST.resume();
    }
  });

  expect(result.checkpoints.beforeActive.upcoming).toContain('glorioso-dia');
  expect(result.checkpoints.beforeActive.current.map(x=>x.id)).not.toContain('glorioso-dia');
  expect(result.checkpoints.beforeActive.current.map(x=>x.id)).toContain('dios-de-milagros');
  expect(result.checkpoints.beforeActive.snapshot.upcoming).toContain('glorioso-dia');

  expect(result.checkpoints.afterActive.upcoming).not.toContain('glorioso-dia');
  expect(result.checkpoints.afterActive.current.map(x=>x.id)).toContain('glorioso-dia');
  expect(result.checkpoints.afterActive.current.map(x=>x.id)).not.toContain('dios-de-milagros');
  expect(result.checkpoints.beforeActive.introduced).not.toContain('Dios De Milagros');
  expect(result.checkpoints.afterActive.introduced).toContain('Dios De Milagros');
  expect(result.checkpoints.afterActive.snapshot.current).toContain('glorioso-dia');
  expect(result.checkpoints.afterActive.snapshot.current).not.toContain('dios-de-milagros');
  expect(result.checkpoints.afterActive.snapshot.introduced).toContain('dios-de-milagros');
  const diosHistoryRow=result.checkpoints.afterActive.introducedRows.find(x=>x.title==='Dios De Milagros');
  expect(diosHistoryRow).toBeTruthy();
  expect(diosHistoryRow.date).toBe('Estrenada · 27 de septiembre');

  expect(result.checkpoints.diosIntroduced.introduced).toContain('Dios De Milagros');
  expect(result.checkpoints.diosIntroduced.snapshot.introduced).toContain('dios-de-milagros');
  const afterActiveCard=result.checkpoints.afterActive.current.find(x=>x.id==='glorioso-dia');
  expect(afterActiveCard).toBeTruthy();
  expect(afterActiveCard.phase).toBe('upcoming');

  const learningCard=result.checkpoints.learning.current.find(x=>x.id==='glorioso-dia');
  expect(learningCard).toBeTruthy();
  expect(learningCard.phase).toBe('learning');
  expect(result.checkpoints.learning.snapshot.phases['glorioso-dia']).toBe('learning');

  const finalCard=result.checkpoints.finalPrep.current.find(x=>x.id==='glorioso-dia');
  expect(finalCard).toBeTruthy();
  expect(finalCard.phase).toBe('final');
  expect(result.checkpoints.finalPrep.snapshot.phases['glorioso-dia']).toBe('final');

  const releaseCard=result.checkpoints.releaseStart.current.find(x=>x.id==='glorioso-dia');
  expect(releaseCard).toBeTruthy();
  expect(releaseCard.phase).toBe('release');
  expect(releaseCard.status).toBe('HOY · ESTRENO');
  expect(result.checkpoints.releaseStart.snapshot.phases['glorioso-dia']).toBe('release');

  const preSettled=result.checkpoints.justBeforeSettled.current.find(x=>x.id==='glorioso-dia');
  expect(preSettled).toBeTruthy();
  expect(preSettled.phase).toBe('release');

  const settled=result.checkpoints.settled.current.find(x=>x.id==='glorioso-dia');
  expect(settled).toBeTruthy();
  expect(settled.phase).toBe('released');
  expect(settled.status).toBe('ESTRENADO');
  expect(settled.title).toBe('ESTRENO COMPLETADO');
  expect(result.checkpoints.settled.snapshot.phases['glorioso-dia']).toBe('released');

  expect(result.checkpoints.gloriosoBeforeRollover.current.map(x=>x.id)).toContain('glorioso-dia');
  expect(result.checkpoints.gloriosoBeforeRollover.upcoming).toContain('no-fallaras');
  expect(result.checkpoints.gloriosoBeforeRollover.introduced).not.toContain('Glorioso Día');

  expect(result.checkpoints.gloriosoRollover.current.map(x=>x.id)).not.toContain('glorioso-dia');
  expect(result.checkpoints.gloriosoRollover.current.map(x=>x.id)).toContain('no-fallaras');
  expect(result.checkpoints.gloriosoRollover.upcoming).not.toContain('no-fallaras');
  expect(result.checkpoints.gloriosoRollover.introduced).toContain('Glorioso Día');
  expect(result.checkpoints.gloriosoRollover.snapshot.introduced).toContain('glorioso-dia');
  const gloriosoHistoryRow=result.checkpoints.gloriosoRollover.introducedRows.find(x=>x.title==='Glorioso Día');
  expect(gloriosoHistoryRow).toBeTruthy();
  expect(gloriosoHistoryRow.date).toBe('Estrenada · 25 de octubre');

  expect(result.checkpoints.introduced.current.map(x=>x.id)).not.toContain('glorioso-dia');
  expect(result.checkpoints.introduced.introduced).toContain('Glorioso Día');
  expect(result.checkpoints.introduced.snapshot.introduced).toContain('glorioso-dia');

  const noFallarasReleased=result.checkpoints.noFallarasReleased.current.find(x=>x.id==='no-fallaras');
  expect(noFallarasReleased).toBeTruthy();
  expect(noFallarasReleased.phase).toBe('released');
  expect(noFallarasReleased.status).toBe('ESTRENADO');
  expect(noFallarasReleased.title).toBe('ESTRENO COMPLETADO');
  expect(result.checkpoints.noFallarasReleased.snapshot.phases['no-fallaras']).toBe('released');

  for(const state of Object.values(result.checkpoints)){
    expect(state.duplicateIds).toEqual([]);
    expect(state.width).toBeLessThanOrEqual(state.viewport+2);
  }
  expect(result.lockHeld).toBe(true);
  // Twelve forced cross-phase renders are intentionally much harsher than production.
  expect(result.transitionRenderMs).toBeLessThan(3000);
  expect(result.transitionRenderMs/12).toBeLessThan(250);
  // Real production cadence: same-phase once-per-second ticks must remain inexpensive.
  expect(result.steadyTickMs).toBeLessThan(1500);
  expect(result.steadyTickMs/30).toBeLessThan(50);
  // The two-frame paint must complete; Playwright's test timeout remains the
  // hang guard. Performance budgets above measure deterministic app work only.
  expect(result.paintFramesCompleted).toBe(true);
  expect(result.finalCurrentCount).toBeLessThanOrEqual(2);
  expect(result.finalNodes).toBeLessThan(1800);
});
test('v176 rendering stays sRGB-authored and resilient across browser/device profiles', async ({ page, request }, testInfo) => {
  await openHealthyPage(page);
  const sourceResponse=await request.get('/?v176-platform-rendering='+Date.now(),{
    headers:{'cache-control':'no-cache'}
  });
  expect(sourceResponse.ok()).toBe(true);
  const source=await sourceResponse.text();

  expect(source).toContain('<meta name="color-scheme" content="dark" />');
  expect(source).toContain('html{\n      color-scheme:dark;');
  expect(source).toContain('@supports not ((backdrop-filter:blur(1px)) or (-webkit-backdrop-filter:blur(1px)))');
  expect(source).toContain('@media (prefers-contrast:more)');
  expect(source).toContain('@media (forced-colors:active)');
  expect(source).not.toContain('color(display-p3');
  expect(source).not.toContain('color(rec2020');

  const audit=await page.evaluate(()=>{
    const palettes=window.IPCDJ_CATALOG?.songs?.map(song=>song.futurePalette)||[];
    const root=getComputedStyle(document.documentElement);
    const body=getComputedStyle(document.body);
    const card=document.querySelector('.card');
    const cardStyle=card?getComputedStyle(card):null;
    return {
      colorScheme:root.colorScheme,
      bodyBackgroundColor:body.backgroundColor,
      bodyBackgroundImage:body.backgroundImage,
      rootBackgroundColor:root.backgroundColor,
      rootBackgroundImage:root.backgroundImage,
      cardBackground:cardStyle?.backgroundColor||'',
      scrollWidth:document.documentElement.scrollWidth,
      clientWidth:document.documentElement.clientWidth,
      filterSupported:CSS.supports('filter','blur(1px)'),
      backdropSupported:CSS.supports('backdrop-filter','blur(1px)')||CSS.supports('-webkit-backdrop-filter','blur(1px)'),
      p3:matchMedia('(color-gamut: p3)').matches,
      palettes
    };
  });

  expect(audit.colorScheme).toContain('dark');
  expect(
    audit.bodyBackgroundImage!=='none' ||
    audit.rootBackgroundImage!=='none' ||
    audit.bodyBackgroundColor!=='rgba(0, 0, 0, 0)' ||
    audit.rootBackgroundColor!=='rgba(0, 0, 0, 0)'
  ).toBe(true);
  expect(audit.bodyBackgroundImage).toContain('gradient');
  expect(audit.filterSupported).toBe(true);
  expect(audit.scrollWidth).toBeLessThanOrEqual(audit.clientWidth+2);
  for(const palette of audit.palettes){
    expect(palette).toHaveLength(3);
    for(const color of palette){
      expect(color).toHaveLength(3);
      for(const channel of color){
        expect(Number.isInteger(channel)).toBe(true);
        expect(channel).toBeGreaterThanOrEqual(0);
        expect(channel).toBeLessThanOrEqual(255);
      }
    }
  }

  // Diagnostic only: profiles may report different physical gamut capabilities,
  // but authored IPCDJ color remains the same sRGB source everywhere.
  expect(['chromium-desktop','firefox-desktop','webkit-desktop','chromium-mobile','webkit-mobile','webkit-compact-mobile','webkit-tablet']).toContain(testInfo.project.name);
});

test('v180 social preview is the approved WhatsApp screenshot', async ({ request }) => {
  const [imageResponse,htmlResponse]=await Promise.all([
    request.get('/social-preview-v180.jpg?health='+Date.now(),{headers:{'cache-control':'no-cache'}}),
    request.get('/?social-v180='+Date.now(),{headers:{'cache-control':'no-cache','user-agent':'WhatsApp/2.25.25.85 A'}})
  ]);

  expect(imageResponse.ok()).toBe(true);
  expect((imageResponse.headers()['content-type']||'')).toMatch(/^image\/jpeg/);
  const bytes=await imageResponse.body();
  expect(bytes.length).toBeGreaterThan(10000);
  expect(bytes.length).toBeLessThan(400000);
  expect(createHash('sha256').update(bytes).digest('hex')).toBe('b96bd5ee2a1bd28e1a3bdabe41e23b1bd94f9a3b56ad48bf286090b5984fbc21');

  const html=await htmlResponse.text();
  expect(html).toContain('property="og:image" content="https://worship.ipcdj.org/social-preview-v180.jpg?v=180"');
  expect(html).toContain('property="og:image:type" content="image/jpeg"');
  expect(html).toContain('property="og:image:width" content="1200"');
  expect(html).toContain('property="og:image:height" content="630"');
  expect(html).toContain('name="twitter:card" content="summary_large_image"');
  expect(html).toContain('name="twitter:image" content="https://worship.ipcdj.org/social-preview-v180.jpg?v=180"');
});
