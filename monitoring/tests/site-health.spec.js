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
  }, null, { timeout: 20000 });

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
      expect(frameSample.max).toBeLessThan(1500);
      expect(frameSample.frames).toBeGreaterThan(3);
      expect(frameSample.over50Ratio).toBeLessThan(0.85);
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
  await expect(homeTab).toHaveAttribute('aria-selected', 'true');
  await expect(homePanel).toBeVisible();
  await expect(weeklyPanel).toBeHidden();

  const launchClassBeforeSwitch = await page.locator('#ipcdj-launch').getAttribute('class');

  await weeklyTab.click();
  await expect(weeklyTab).toHaveAttribute('aria-selected', 'true');
  await expect(weeklyPanel).toBeVisible();
  await expect(homePanel).toBeHidden();
  await expect(weeklyPanel.getByText('Próximamente')).toBeVisible();
  await expect(weeklyPanel).toContainText(/viernes/i);
  await expect(weeklyPanel).toContainText(/domingo/i);
  await expect(weeklyPanel).not.toHaveClass(/site-tab-panel-enter/);

  const launchClassAfterSwitch = await page.locator('#ipcdj-launch').getAttribute('class');
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

  await page.evaluate(() => {
    window.IPCDJ_NAV.syncSpecialEvents(Date.parse('2026-10-12T00:00:00-04:00'));
  });

  await expect(page.locator('#tab-campana-gu-2026')).toHaveCount(0);
  await expect(homeTab).toHaveAttribute('aria-selected', 'true');
  await expect(homePanel).toBeVisible();

  await page.evaluate(() => window.IPCDJ_NAV.syncSpecialEvents(Date.now()));

  const phaseState = await page.locator('[data-current-song-card]').first().evaluate(card => {
    const phase = card.dataset.phase || '';
    const timeline = card.querySelector('.timeline');
    const items = [...card.querySelectorAll('.timeline-item')];
    const active = items.filter(item => item.classList.contains('active-phase'));
    const inactive = items.filter(item => !item.classList.contains('active-phase'));

    return {
      phase,
      timelineDisplay: timeline ? getComputedStyle(timeline).display : 'none',
      activeCount: active.length,
      activeRole: active[0]?.dataset.role || '',
      activeShadow: active[0] ? getComputedStyle(active[0]).boxShadow : 'none',
      inactive: inactive.map(item => ({
        shadow: getComputedStyle(item).boxShadow,
        opacity: Number(getComputedStyle(item).opacity)
      }))
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

