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
    expect(frameSample.max).toBeLessThan(1500);

    if (/webkit/i.test(testInfo.project.name)) {
      expect(frameSample.frames).toBeGreaterThan(0);
    } else {
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
      return {
        leftDelta: Math.abs(ringRect.left - buttonRect.left),
        topDelta: Math.abs(ringRect.top - buttonRect.top),
        widthDelta: Math.abs(ringRect.width - buttonRect.width),
        heightDelta: Math.abs(ringRect.height - buttonRect.height),
        trackRadius: track.getAttribute('r'),
        progressRadius: progress.getAttribute('r')
      };
    });

    expect(ringAlignment).not.toBeNull();
    expect(ringAlignment.leftDelta).toBeLessThanOrEqual(0.6);
    expect(ringAlignment.topDelta).toBeLessThanOrEqual(0.6);
    expect(ringAlignment.widthDelta).toBeLessThanOrEqual(0.6);
    expect(ringAlignment.heightDelta).toBeLessThanOrEqual(0.6);
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
