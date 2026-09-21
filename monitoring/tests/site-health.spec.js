import { test, expect } from '@playwright/test';

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
    .toHaveAttribute('content', /persistent-launch-v\d+/);

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
    const nav = document.querySelector('.site-nav');
    const hero = document.querySelector('.hero');
    if (!nav || !hero) return null;
    const tabs = [...nav.querySelectorAll('[role="tab"]')];
    const widths = tabs.map(tab => tab.getBoundingClientRect().width);
    const heights = tabs.map(tab => tab.getBoundingClientRect().height);
    const navRect = nav.getBoundingClientRect();
    return {
      navBeforeHero: !!(nav.compareDocumentPosition(hero) & Node.DOCUMENT_POSITION_FOLLOWING),
      position: getComputedStyle(nav).position,
      navWidth: navRect.width,
      viewportWidth: window.innerWidth,
      widths,
      heights
    };
  });

  expect(navLayout).not.toBeNull();
  expect(navLayout.navBeforeHero).toBe(true);
  expect(navLayout.position).toBe('relative');
  expect(navLayout.navWidth).toBeLessThanOrEqual(navLayout.viewportWidth);
  expect(Math.max(...navLayout.widths) - Math.min(...navLayout.widths)).toBeLessThanOrEqual(1.5);
  expect(Math.max(...navLayout.heights) - Math.min(...navLayout.heights)).toBeLessThanOrEqual(1.5);

  await expect(homeTab).toHaveAttribute('aria-selected', 'true');
  await expect(homePanel).toBeVisible();
  await expect(weeklyPanel).toBeHidden();

  const launch = page.locator('#ipcdj-launch');
  const launchClassBeforeSwitch = await launch.getAttribute('class');

  // Reproduce the standalone-iOS ordering that triggered the regression:
  // internal touch/pointer begins, then a stray window blur arrives before click.
  await weeklyTab.dispatchEvent('pointerdown', { pointerType: 'touch', isPrimary: true });
  await page.evaluate(() => window.dispatchEvent(new Event('blur')));
  await expect(launch).toHaveAttribute('class', launchClassBeforeSwitch || 'launch-idle');

  await weeklyTab.click();
  await expect(weeklyTab).toHaveAttribute('aria-selected', 'true');
  await expect(weeklyPanel).toBeVisible();
  await expect(homePanel).toBeHidden();
  await expect(weeklyPanel.getByText('Próximamente')).toBeVisible();
  await expect(weeklyPanel).toContainText(/viernes/i);
  await expect(weeklyPanel).toContainText(/domingo/i);
  await expect(weeklyPanel).not.toHaveClass(/site-tab-panel-enter/);

  const launchClassAfterSwitch = await launch.getAttribute('class');
  expect(launchClassAfterSwitch).toBe(launchClassBeforeSwitch);

  await weeklyTab.focus();
  await page.keyboard.press('Home');
  await expect(homeTab).toBeFocused();
  await expect(homeTab).toHaveAttribute('aria-selected', 'true');

  await page.evaluate(() => {
    window.IPCDJ_NAV.syncSpecialEvents(Date.parse('2026-10-11T23:59:59-04:00'));
  });

  const eventTab = page.locator('#tab-campana-gu-2026');
  await expect(eventTab).toBeVisible();
  await eventTab.click();

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
    // Restore the live-date state inside the same task so the one-second render
    // loop cannot race the synthetic expiry assertion.
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
        const complete = api.phase(song.id, Date.parse(song.introducedAt));
        const atActive = api.snapshot(Date.parse(song.activeFrom));
        const atIntroduced = api.snapshot(Date.parse(song.introducedAt));
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
  expect(source).not.toContain('Math.min(index,40)*260');

  for (const id of ids) {
    const escaped = id.replace(/[-/\\^$*+?.()|[\]{}]/g, '\\$&');
    const occurrences = (source.match(new RegExp(escaped, 'g')) || []).length;
    expect(occurrences, id + ' should be authored only once in SONG_CATALOG_SOURCE').toBe(1);
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

      const state = await card.evaluate(node => {
        const css = getComputedStyle(node);
        return {
          url: node.dataset.coverArtworkUrl || '',
          source: node.dataset.coverArtworkSource || '',
          artworkId: node.dataset.coverArtwork || '',
          themeId: node.dataset.coverTheme || '',
          c1: css.getPropertyValue('--cover-c1').trim(),
          c2: css.getPropertyValue('--cover-c2').trim(),
          c3: css.getPropertyValue('--cover-c3').trim()
        };
      });

      expect(state.url).toBe(expectedUrl);
      expect(state.source).toBe(expectedSource);
      expect(state.artworkId).toBe(song.id);
      expect(state.themeId).toBe(song.id);
      expect(state.c1.length).toBeGreaterThan(0);
      expect(state.c2.length).toBeGreaterThan(0);
      expect(state.c3.length).toBeGreaterThan(0);
    }
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
  expect(serviceWorkerText).toContain('ipcdj-worship-v');

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

