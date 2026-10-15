import { test, expect } from '@playwright/test';

test.describe('stable Reinas visuals and scroll glass', () => {
  test.beforeEach(async ({}, testInfo) => {
    test.skip(testInfo.project.name !== 'chromium-desktop',
      'Mac desktop regression evaluated in Chromium; existing site-health suite covers all seven device profiles');
  });

  test('Reinas TBD uses the same cover palette before and after interaction', async ({ page }) => {
    await page.goto('/', { waitUntil: 'domcontentloaded' });
    const card=page.locator('[data-song-id="reinas-por-la-eternidad"]');
    await expect(card).toBeAttached();
    const view=()=>card.evaluate(el=>{
      const css=getComputedStyle(el);
      return {
        theme:el.classList.contains('future-themed'),
        palette:[1,2,3,4].map(i=>css.getPropertyValue('--future-c'+i).trim()),
        accent:css.getPropertyValue('--future-accent').trim(),
        label:el.querySelector('.song-date')?.textContent?.trim()
      };
    });
    const before=await view();
    expect(before.theme).toBe(true);
    expect(before.palette.every(x=>x.length>4)).toBe(true);
    expect(before.label).toBe('Estreno: Por definir');
    await card.dispatchEvent('pointerdown', { pointerType:'mouse', isPrimary:true });
    await expect.poll(()=>card.evaluate(el=>!!el.dataset.futureHydrationRequested),{timeout:6000}).toBe(true);
    const after=await view();
    expect(after.palette).toEqual(before.palette);
    expect(after.accent).toBe(before.accent);
  });

  test('Mac desktop scroll retains frosted glass and moving background', async ({ page }) => {
    await page.addInitScript(()=>{
      Object.defineProperty(navigator,'userAgent',{
        configurable:true,get:()=> 'Mozilla/5.0 (Macintosh; Intel Mac OS X 13_7) AppleWebKit/537.36 Chrome/154.0.0.0 Safari/537.36'
      });
      Object.defineProperty(navigator,'maxTouchPoints',{configurable:true,get:()=>0});
    });
    await page.goto('/', { waitUntil:'domcontentloaded' });
    await page.waitForFunction(()=>!!document.querySelector('.ambient-field-active .ambient-blob.b1'));
    const status=()=>page.evaluate(()=>{
      const card=document.querySelector('.card');
      const blob=document.querySelector('.ambient-field-active .ambient-blob.b1');
      const s=card?getComputedStyle(card):null;
      return {
        glass:s?.backdropFilter||s?.webkitBackdropFilter||'',
        anim:blob?getComputedStyle(blob).animationPlayState:'',
        altered:document.documentElement.classList.contains('ipcdj-scroll-active')
      };
    });
    const initial=await status();
    expect(initial.glass).toContain('blur(');
    expect(initial.anim).toContain('running');
    await page.evaluate(()=>window.scrollTo(0,650));
    await page.waitForFunction(()=>window.scrollY>200);
    const scroll=await status();
    expect(scroll.glass).toBe(initial.glass);
    expect(scroll.anim).toContain('running');
    expect(scroll.altered).toBe(false);
  });
});
