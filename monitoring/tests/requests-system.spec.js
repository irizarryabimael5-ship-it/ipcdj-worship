import {test,expect} from "@playwright/test";

// Staging-only: Live has not approved this feature, so these cases must
// never assume request UI is in the production branch.
test.skip(!/staging/i.test(process.env.IPCDJ_BASE_URL||""),"Staging-only request integration");

const API="**/ipcdj-song-requests-staging.ipcdjofficial.workers.dev";
async function openRequests(page){
  await page.goto("/?requests-e2e="+Date.now(),{waitUntil:"domcontentloaded"});
  await page.waitForFunction(()=>(
    !!window.IPCDJ_CATALOG_HEALTH&&
    !!document.querySelector("#requested-songs .song-row")
  ),null,{timeout:20000});
  await page.waitForFunction(()=>{
    const launch=document.getElementById("ipcdj-launch");
    if(!launch)return true;
    const css=getComputedStyle(launch);
    return launch.classList.contains("launch-idle")||
      (!document.documentElement.classList.contains("ipcdj-launch-active")&&
      (css.visibility==="hidden"||Number(css.opacity)<=0.01));
  },null,{timeout:30000});
  await page.locator("#tab-solicitudes").click();
  await expect(page.locator("#panel-solicitudes")).toBeVisible();
}
test("requests form appears without enabling unfinished public intake",async({page})=>{
  await page.route(API+"/health",route=>route.fulfill({
    status:200,contentType:"application/json",headers:{"access-control-allow-origin":"*"},
    body:JSON.stringify({ok:true,environment:"staging",storageConfigured:true,
      intakeEnabled:false,notificationsEnabled:false,publicationEnabled:false})
  }));
  await page.route(API+"/v1/requests",route=>route.fulfill({
    status:200,contentType:"application/json",headers:{"access-control-allow-origin":"*"},
    body:JSON.stringify({ok:true,songs:[]})
  }));
  await openRequests(page);
  await expect(page.locator("#requested-songs [data-request-song-id]")).toHaveCount(1);
  await expect(page.locator("#requested-songs")).toContainText("Háblame de Cerca");
  await expect(page.locator("#song-request-form input[name=title]")).toBeVisible();
  await expect(page.locator("#song-request-form input[name=artist]")).toBeVisible();
  await expect(page.locator("#requests-submit")).toBeDisabled();
  await expect(page.locator("#requests-form-status")).toContainText("Estamos preparando");
  await expect(page.locator("#requested-songs")).toContainText("Solicitada");
  const overflow=await page.evaluate(()=>document.documentElement.scrollWidth-innerWidth);
  expect(overflow).toBeLessThanOrEqual(2);
});
test("published feed stacks newest first, escapes untrusted markup and deduplicates pilot",async({page})=>{
  const published=[
    {id:"c9692e06-7d2c-4d0d-bce9-2b79f2c24304",
      title:"Vida Nueva <img src=x onerror=alert(1)>",artist:"Música de prueba",
      status:"Solicitada",publishedAt:"2026-10-17T12:00:00Z",requestCount:4,
      artworkUrl:"",previewUrl:"",metadata:{futurePalette:[[36,60,120],[99,50,100],[12,35,75]]}},
    {id:"c9692e06-7d2c-4d0d-bce9-2b79f2c24305",
      title:"Háblame de Cerca",artist:"Grupo Grace & Kairo Worship",
      status:"Solicitada",publishedAt:"2026-10-16T19:00:00Z",requestCount:2,
      artworkUrl:"",previewUrl:"",metadata:{}},
    {id:"c9692e06-7d2c-4d0d-bce9-2b79f2c24306",
      title:"Should never publish",artist:"Unapproved",
      status:"pending",publishedAt:"2026-10-17T19:00:00Z",requestCount:1,
      artworkUrl:"",previewUrl:"",metadata:{}}
  ];
  await page.route(API+"/health",route=>route.fulfill({
    status:200,contentType:"application/json",headers:{"access-control-allow-origin":"*"},
    body:JSON.stringify({ok:true,environment:"staging",storageConfigured:true,
      intakeEnabled:false,notificationsEnabled:false,publicationEnabled:false})
  }));
  await page.route(API+"/v1/requests",route=>route.fulfill({
    status:200,contentType:"application/json",headers:{"access-control-allow-origin":"*"},
    body:JSON.stringify({ok:true,songs:published})
  }));
  await openRequests(page);
  await expect(page.locator("#requested-songs [data-request-song-id]")).toHaveCount(2);
  await expect(page.locator("#requested-songs .song-row").first()).toContainText("Vida Nueva");
  await expect(page.locator("#requested-songs .song-row").first()).toContainText("4 solicitudes");
  await expect(page.locator("#requested-songs")).toContainText("Adelanto no disponible");
  await expect(page.locator("#requested-songs")).not.toContainText("Should never publish");
  await expect(page.locator("#requested-songs img")).toHaveCount(0);
  expect(await page.evaluate(()=>document.querySelectorAll("#requested-songs [onerror]").length)).toBe(0);
  await expect(page.locator("#requests-submit")).toBeDisabled();
});
test("unavailable provider leaves the approved Staging request card intact",async({page})=>{
  await page.route(API+"/health",route=>route.abort());
  await page.route(API+"/v1/requests",route=>route.abort());
  await openRequests(page);
  await expect(page.locator("#requested-songs")).toContainText("Háblame de Cerca");
  await expect(page.locator("#requests-submit")).toBeDisabled();
  await expect(page.locator("#requested-feed-status")).toContainText("Sin conexión");
});
