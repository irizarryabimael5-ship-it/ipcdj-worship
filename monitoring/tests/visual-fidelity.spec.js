import { test, expect } from '@playwright/test';

test.describe('First-paint Reinas art, scrolling glass, essential navigation',()=>{
  test.beforeEach(async ({},info)=>{
    test.skip(info.project.name!=='chromium-desktop','Mac-focused regression; general health suite runs all seven profiles');
  });

  test('Reinas has stable colors before and after interaction',async({page})=>{
    await page.goto('/',{waitUntil:'domcontentloaded'});
    const card=page.locator('[data-song-id="reinas-por-la-eternidad"]');
    await expect(card).toBeAttached();
    const styles=()=>card.evaluate(el=>{
      const css=getComputedStyle(el);
      return {
        themed:el.classList.contains('future-themed'),
        palette:[1,2,3,4].map(i=>css.getPropertyValue('--future-c'+i).trim()),
        accent:css.getPropertyValue('--future-accent').trim(),
        date:el.querySelector('.song-date')?.textContent?.trim()
      };
    });
    const first=await styles();
    expect(first.themed).toBe(true);
    expect(first.palette.every(x=>x.length>4)).toBe(true);
    expect(first.date).toBe('Estreno: Por definir');
    await card.dispatchEvent('pointerdown',{pointerType:'mouse',isPrimary:true});
    await expect.poll(()=>card.evaluate(el=>!!el.dataset.futureHydrationRequested)).toBe(true);
    await page.waitForTimeout(950);
    const later=await styles();
    expect(later.palette).toEqual(first.palette);
    expect(later.accent).toBe(first.accent);
  });

  test('glass and ambient motion remain consistent through Mac scrolling',async({page})=>{
    await page.goto('/',{waitUntil:'domcontentloaded'});
    await page.waitForFunction(()=>!!document.querySelector('.ambient-field-active .ambient-blob.b1'));
    const measure=()=>page.evaluate(()=>{
      const card=document.querySelector('.card');
      const blob=document.querySelector('.ambient-field-active .ambient-blob.b1');
      const css=card?getComputedStyle(card):null;
      return {
        glass:css?.backdropFilter||css?.webkitBackdropFilter||'',
        motion:blob?getComputedStyle(blob).animationPlayState:'',
        scrolling:document.documentElement.classList.contains('ipcdj-scroll-active')
      };
    });
    const before=await measure();
    expect(before.glass).toContain('blur(');
    expect(before.motion).toContain('running');
    await page.evaluate(()=>window.scrollTo(0,650));
    await expect.poll(()=>page.evaluate(()=>scrollY)).toBeGreaterThan(100);
    const during=await measure();
    expect(during.glass).toBe(before.glass);
    expect(during.motion).toContain('running');
    expect(during.scrolling).toBe(false);
    // A legacy class should not flatten the glass even on stale PWA state.
    await page.evaluate(()=>document.documentElement.classList.add('ipcdj-macos-desktop','ipcdj-scroll-active'));
    const legacy=await measure();
    expect(legacy.glass).toBe(before.glass);
    expect(legacy.motion).toContain('running');
  });

  test('Inicio and Worship semanal work and the October 23 Friday and October 25 Sunday sets remain intact',async({page})=>{
    await page.clock.setFixedTime(new Date('2026-10-15T12:00:00-04:00'));
    await page.goto('/',{waitUntil:'domcontentloaded'});
    await expect(page.locator('[data-song-id="reinas-por-la-eternidad"]')).toBeAttached();
    await expect(page.locator('[data-song-id="no-fallaras"]')).toBeAttached();
    await expect(page.locator('.site-tab')).toHaveCount(3);
    await page.locator('#tab-worship-semanal').click();
    await expect(page.locator('#panel-worship-semanal')).toBeVisible();
    const friday=page.locator('#weekly-panel-viernes');
    await expect(friday.locator('.weekly-song')).toHaveCount(4);
    await expect(friday).toContainText('Viernes, 23 de octubre');
    await page.locator('#weekly-tab-domingo').click();
    const sunday=page.locator('#weekly-panel-domingo');
    await expect(sunday).toBeVisible();
    await expect(sunday.locator('.weekly-song')).toHaveCount(5);
    await expect(sunday).toContainText('Domingo, 25 de octubre');
    await expect(page.locator('.weekly-history[data-weekly-archive-cycle="2026-10-18"] .weekly-song')).toHaveCount(9);
    await page.locator('#tab-inicio').click();
    await expect(page.locator('[data-song-id="reinas-por-la-eternidad"]')).toBeAttached();
  });
});
