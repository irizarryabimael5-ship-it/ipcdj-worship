import {test,expect} from '@playwright/test';

test.describe('Intelligent Eastern-time calendar (v200)',()=>{
  test.beforeEach(async ({},testInfo)=>{
    test.skip(testInfo.project.name!=='chromium-desktop',
      'Calendar state/timeline tested with desktop clock; existing site health runs all seven profiles');
  });

  test('calculates the actual week independently from the published set across DST and New Year',async({page})=>{
    await page.clock.setFixedTime(new Date('2026-10-15T12:00:00-04:00'));
    await page.goto('/',{waitUntil:'domcontentloaded'});
    await page.waitForFunction(()=>!!window.IPCDJ_CALENDAR);
    const contexts=await page.evaluate(()=>{
      const instants=[
        '2026-10-15T12:00:00-04:00', // original authored week
        '2026-10-19T12:00:00-04:00', // following Monday, without new song publishing
        '2026-11-01T12:00:00-05:00', // DST fall-back
        '2027-01-01T12:00:00-05:00'  // year crossover
      ];
      return instants.map(when=>window.IPCDJ_CALENDAR.getContext(Date.parse(when)));
    });
    expect(contexts.map(x=>x.currentWeekStart)).toEqual(['2026-10-12','2026-10-19','2026-10-26','2026-12-28']);
    expect(contexts.map(x=>x.currentFriday)).toEqual(['2026-10-16','2026-10-23','2026-10-30','2027-01-01']);
    expect(contexts.map(x=>x.currentSunday)).toEqual(['2026-10-18','2026-10-25','2026-11-01','2027-01-03']);
    expect(contexts.map(x=>x.nextService.date)).toEqual(['2026-10-16','2026-10-23','2026-11-06','2027-01-01']);
    expect(contexts.map(x=>x.publishedIsCurrentWeek)).toEqual([true,false,false,false]);
    expect(contexts.every(x=>x.cycle==='2026-10-18'&&x.timeZone==='America/New_York')).toBe(true);
    expect(contexts[1].phase).toBe('cerrada');
    await expect(page.locator('#weekly-panel-viernes .weekly-song')).toHaveCount(4);
    await expect(page.locator('#weekly-panel-domingo .weekly-song')).toHaveCount(5);
  });

  test('wakes across midnight and reports only meaningful changes',async({page})=>{
    await page.clock.setFixedTime(new Date('2026-10-15T23:58:00-04:00'));
    await page.goto('/',{waitUntil:'domcontentloaded'});
    await page.waitForFunction(()=>!!window.IPCDJ_CALENDAR);
    await page.evaluate(()=>{
      window.__calendarEvents=[];
      window.addEventListener('ipcdj:calendarchange',event=>{
        window.__calendarEvents.push({day:event.detail.context.localDate,reason:event.detail.reason});
      });
    });
    await page.clock.setFixedTime(new Date('2026-10-16T00:01:00-04:00'));
    await page.evaluate(()=>window.dispatchEvent(new Event('pageshow')));
    await expect.poll(()=>page.evaluate(()=>window.IPCDJ_CALENDAR.getSnapshot().localDate)).toBe('2026-10-16');
    await expect.poll(()=>page.evaluate(()=>window.__calendarEvents.length)).toBe(1);
    expect(await page.evaluate(()=>window.IPCDJ_CALENDAR.getSnapshot().serviceToday)).toBe('viernes');
    await page.evaluate(()=>window.dispatchEvent(new Event('focus')));
    expect(await page.evaluate(()=>window.__calendarEvents.length)).toBe(1);
    await expect(page.locator('#weekly-panel-viernes .weekly-song')).toHaveCount(4);
    await expect(page.locator('#weekly-panel-domingo .weekly-song')).toHaveCount(5);
  });

  test('archives once at the configured Sunday cutoff, not before, with playlists removed',async({page})=>{
    await page.clock.setFixedTime(new Date('2026-10-15T12:00:00-04:00'));
    await page.goto('/',{waitUntil:'domcontentloaded'});
    await page.waitForFunction(()=>!!window.IPCDJ_CALENDAR&&!!window.IPCDJ_WEEKLY_TEST);
    const before=await page.evaluate(()=>window.IPCDJ_CALENDAR.refresh(Date.parse('2026-10-18T14:59:59-04:00')));
    expect(before.activeState).toBe('active');
    expect(before.rolloverDue).toBe(false);
    await expect(page.locator('#weekly-panel-viernes .weekly-song')).toHaveCount(4);
    const after=await page.evaluate(()=>window.IPCDJ_CALENDAR.refresh(Date.parse('2026-10-18T15:00:00-04:00')));
    expect(after.activeState).toBe('rolled');
    expect(after.rolloverDue).toBe(true);
    const archive=page.locator('[data-weekly-history-body][data-weekly-history-cycle="2026-10-18"]');
    await expect(archive).toBeAttached();
    await expect(archive.locator('.weekly-history-service')).toHaveCount(2);
    await expect(archive.locator('.weekly-song')).toHaveCount(9);
    await expect(archive.locator('iframe')).toHaveCount(0);
    await expect(archive.locator('a[href*="youtube.com/playlist"]')).toHaveCount(0);
    await expect(page.locator('#weekly-panel-viernes .weekly-song')).toHaveCount(0);
    await expect(page.locator('#weekly-panel-domingo .weekly-song')).toHaveCount(0);
    await page.evaluate(()=>window.IPCDJ_CALENDAR.refresh(Date.parse('2026-10-18T15:00:01-04:00')));
    await expect(page.locator('[data-weekly-history-body][data-weekly-history-cycle="2026-10-18"] .weekly-history-service')).toHaveCount(2);
  });

  test('main and nested tabs still work without automatic weekday switching',async({page})=>{
    await page.clock.setFixedTime(new Date('2026-10-16T12:00:00-04:00'));
    await page.goto('/',{waitUntil:'domcontentloaded'});
    await page.waitForFunction(()=>!!window.IPCDJ_CALENDAR);
    await page.locator('#tab-worship-semanal').click();
    await expect(page.locator('#weekly-tab-viernes')).toHaveAttribute('aria-selected','true');
    await page.locator('#weekly-tab-domingo').click();
    await expect(page.locator('#weekly-panel-domingo')).toBeVisible();
    // Advance the actual browser wall clock along with the calendar.
    // An explicit refresh into Saturday alone is temporary: navigation
    // correctly recalculates from the Friday wall clock on the next event.
    await page.clock.setFixedTime(new Date('2026-10-17T12:00:00-04:00'));
    await page.evaluate(()=>window.IPCDJ_CALENDAR.refresh());
    await expect(page.locator('#weekly-panel-domingo')).toBeVisible();
    expect(await page.evaluate(()=>window.IPCDJ_CALENDAR.getSnapshot().nextService.date)).toBe('2026-10-18');
    await page.locator('#tab-inicio').click();
    await expect(page.locator('#panel-inicio')).toBeVisible();
    expect(await page.evaluate(()=>window.IPCDJ_CALENDAR.getSnapshot().nextService.date)).toBe('2026-10-18');
  });
});
