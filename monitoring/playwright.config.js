import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  timeout: 45000,
  expect: { timeout: 12000 },
  retries: process.env.CI ? 1 : 0,
  workers: process.env.CI ? 3 : undefined,
  reporter: [
    ['line'],
    ['html', { outputFolder: 'playwright-report', open: 'never' }]
  ],
  use: {
    baseURL: process.env.IPCDJ_BASE_URL || 'https://worship.ipcdj.org',
    locale: 'es-ES',
    timezoneId: 'America/New_York',
    ignoreHTTPSErrors: false,
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure'
  },
  projects: [
    {
      name: 'chromium-desktop',
      use: { ...devices['Desktop Chrome'], browserName: 'chromium' }
    },
    {
      name: 'firefox-desktop',
      use: { ...devices['Desktop Firefox'], browserName: 'firefox' }
    },
    {
      name: 'webkit-desktop',
      use: { ...devices['Desktop Safari'], browserName: 'webkit' }
    },
    {
      name: 'chromium-mobile',
      use: { ...devices['Pixel 7'], browserName: 'chromium' }
    },
    {
      name: 'webkit-mobile',
      use: { ...devices['iPhone 15'], browserName: 'webkit' }
    },
    {
      name: 'webkit-tablet',
      use: {
        browserName: 'webkit',
        viewport: { width: 1024, height: 1366 },
        screen: { width: 1024, height: 1366 },
        deviceScaleFactor: 2,
        isMobile: true,
        hasTouch: true
      }
    }
  ]
});
