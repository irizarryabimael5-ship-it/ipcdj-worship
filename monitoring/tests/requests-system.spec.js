import {test,expect} from "@playwright/test";

// Staging-only: Live has not approved this feature, so these cases must
// never assume request UI is in the production branch.
test.skip(!/staging/i.test(process.env.IPCDJ_BASE_URL||""),"Staging-only request integration");

// Keep provider mocks at window.fetch, before application scripts execute.
// Playwright route interception is inconsistent when a browser's service worker
// owns the external fetch; the mocked UI contract must never contact real D1.
test.use({serviceWorkers:"block"});
async function installApiMock(page,{songs=[],offline=false}={}){
  await page.addInitScript(({songs,offline})=>{
    const nativeFetch=window.fetch.bind(window);
    window.__IPCDJ_REQUESTS_E2E={feedCalls:0,healthCalls:0};
    window.fetch=(input,options)=>{
      const url=typeof input==="string"?input:input?.url;
      if(typeof url==="string"&&url.startsWith("https://ipcdj-song-requests-staging.ipcdjofficial.workers.dev/")){
        const path=new URL(url).pathname;
        const feed=path==="/v1/requests",health=path==="/health";
        if(feed||health){
          if(feed)window.__IPCDJ_REQUESTS_E2E.feedCalls++;
          else window.__IPCDJ_REQUESTS_E2E.healthCalls++;
          if(offline)return Promise.reject(new TypeError("Simulated provider network failure"));
          const payload=feed?{ok:true,songs}:{ok:true,environment:"staging",
            storageConfigured:true,intakeEnabled:false,
            notificationsEnabled:false,publicationEnabled:false};
          return Promise.resolve(new Response(JSON.stringify(payload),{
            status:200,headers:{"Content-Type":"application/json",
              "Access-Control-Allow-Origin":"*"}
          }));
        }
      }
      return nativeFetch(input,options);
    };
  },{songs,offline});
}

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
  await page.waitForFunction(()=>window.__IPCDJ_REQUESTS_E2E?.feedCalls>0,null,{timeout:12000});
  await expect(page.locator("#panel-solicitudes")).toBeVisible();
}
test("requests form appears without enabling unfinished public intake",async({page})=>{
  await installApiMock(page,{songs:[]});
  await openRequests(page);
  await expect(page.locator("#requested-songs [data-request-song-id]")).toHaveCount(5);
  expect(await page.locator("#requested-songs .song-top h3").allTextContents()).toEqual(["Háblame de Cerca","El Nombre De Jesús","Agradecido Estoy","Poderoso Dios (Grande y Fiel)","Bienvenido Espíritu Santo"]);
  await expect(page.locator("#requested-songs [data-preview-song-id]")).toHaveCount(4);
  await expect(page.locator("#requested-songs")).toContainText("Háblame de Cerca");
  await expect(page.locator("#song-request-form input[name=title]")).toBeVisible();
  await expect(page.locator("#song-request-form input[name=artist]")).toBeVisible();
  await expect(page.locator("#requests-submit")).toBeDisabled();
  await expect(page.locator("#requests-form-status")).toContainText("Estamos preparando");
  await expect(page.locator("#requested-songs")).toContainText("Solicitada");
  const overflow=await page.evaluate(()=>document.documentElement.scrollWidth-innerWidth);
  expect(overflow).toBeLessThanOrEqual(2);
});
test("published feed preserves the curated sequence, escapes markup and deduplicates pilot",async({page})=>{
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
  await installApiMock(page,{songs:published});
  await openRequests(page);
  await expect(page.locator("#requested-songs [data-request-song-id]")).toHaveCount(6);
  expect(await page.locator("#requested-songs .song-top h3").allTextContents()).toEqual([
    "Háblame de Cerca","El Nombre De Jesús","Agradecido Estoy","Poderoso Dios (Grande y Fiel)",
    "Bienvenido Espíritu Santo","Vida Nueva <img src=x onerror=alert(1)>"
  ]);
  await expect(page.locator("#requested-songs .song-row").first()).toContainText("2 solicitudes");
  await expect(page.locator("#requested-songs .song-row").last()).toContainText("4 solicitudes");
  await expect(page.locator("#requested-songs")).toContainText("Adelanto no disponible");
  await expect(page.locator("#requested-songs")).not.toContainText("Should never publish");
  await expect(page.locator("#requested-songs img")).toHaveCount(0);
  expect(await page.evaluate(()=>document.querySelectorAll("#requested-songs [onerror]").length)).toBe(0);
  await expect(page.locator("#requests-submit")).toBeDisabled();
});
test("unavailable provider leaves the approved Staging request card intact",async({page})=>{
  await installApiMock(page,{offline:true});
  await openRequests(page);
  expect(await page.locator("#requested-songs .song-top h3").allTextContents()).toEqual(["Háblame de Cerca","El Nombre De Jesús","Agradecido Estoy","Poderoso Dios (Grande y Fiel)","Bienvenido Espíritu Santo"]);
  await expect(page.locator("#requests-submit")).toBeDisabled();
  await expect(page.locator("#requested-feed-status")).toContainText("Sin conexión");
});
