import {test,expect} from "@playwright/test";

// Staging-only functional integration. Mock provider transport, not the audio
// engine: a real browser AudioContext must decode & play actual WAV bytes.
test.skip(!/staging/i.test(process.env.IPCDJ_BASE_URL||""),
  "Owner has not approved these preview features for Live");
test.use({serviceWorkers:"block"});

async function installAudioFixture(page){
  await page.addInitScript(()=>{
    const originalFetch=window.fetch.bind(window);
    const known={
      "1884087646":["Háblame de Cerca","Grupo Grace & Kairo Worship"],
      "1873032536":["El Nombre De Jesús","Elevation Español"],
      "1873032528":["Agradecido Estoy","Elevation Español"],
      "1699411330":["Poderoso Dios (Grande y Fiel)","Gateway Worship Español & Miel San Marcos"],
      "1799832312":["Santo Es El Que Vive","Montesanto"],
      "1777898241":["Con Poder","Barak"]
    };
    const albumId="1783806472";
    const bufferById=new Map();
    window.__IPCDJ_AUDIO_QA={providerLookups:[],audioFetches:[]};

    function fixtureWave(id){
      if(bufferById.has(id))return bufferById.get(id);
      const sampleRate=16000,seconds=7,samples=sampleRate*seconds;
      const data=new ArrayBuffer(44+samples*2),view=new DataView(data);
      function word(offset,value){view.setUint32(offset,value,true)}
      function short(offset,value){view.setUint16(offset,value,true)}
      for(let i=0;i<4;i++)view.setUint8(i,"RIFF".charCodeAt(i));
      word(4,data.byteLength-8);
      for(let i=0;i<4;i++)view.setUint8(8+i,"WAVE".charCodeAt(i));
      for(let i=0;i<4;i++)view.setUint8(12+i,"fmt ".charCodeAt(i));
      word(16,16);short(20,1);short(22,1);word(24,sampleRate);
      word(28,sampleRate*2);short(32,2);short(34,16);
      for(let i=0;i<4;i++)view.setUint8(36+i,"data".charCodeAt(i));
      word(40,samples*2);
      for(let i=0;i<samples;i++){
        const t=i/sampleRate;
        const attack=Math.min(1,t/.25),release=Math.min(1,(seconds-t)/.7);
        const sample=Math.sin(t*Math.PI*2*220)*Math.min(attack,release)*.14;
        view.setInt16(44+i*2,Math.round(sample*32767),true);
      }
      bufferById.set(id,data);
      return data;
    }
    function jsonResponse(obj){return Promise.resolve(new Response(JSON.stringify(obj),{
      status:200,headers:{"content-type":"application/json","access-control-allow-origin":"*"}
    }))}
    window.fetch=(input,init)=>{
      const url=typeof input==="string"?input:input?.url||"";
      if(url.startsWith("https://itunes.apple.com/lookup?")){
        const params=new URL(url).searchParams,id=params.get("id");
        window.__IPCDJ_AUDIO_QA.providerLookups.push(id);
        if(id===albumId){
          return jsonResponse({resultCount:2,results:[
            {wrapperType:"collection",collectionId:Number(id),collectionName:"Fuego & Poder (Live)"},
            {wrapperType:"track",trackId:9000101,collectionId:Number(id),
              trackName:"Bienvenido Espíritu Santo (Live)",artistName:"Barak",
              previewUrl:"https://audio-ssl.itunes.apple.com/ipcdj-qa/9000101.wav"}
          ]});
        }
        if(known[id]){
          const [trackName,artistName]=known[id];
          return jsonResponse({resultCount:1,results:[{
            wrapperType:"track",trackId:Number(id),trackName,artistName,
            previewUrl:"https://audio-ssl.itunes.apple.com/ipcdj-qa/"+id+".wav"
          }]});
        }
      }
      if(url.startsWith("https://audio-ssl.itunes.apple.com/ipcdj-qa/")){
        const id=url.split("/").pop().replace(".wav","");
        window.__IPCDJ_AUDIO_QA.audioFetches.push(id);
        return Promise.resolve(new Response(fixtureWave(id).slice(0),{
          status:200,headers:{"content-type":"audio/wav","access-control-allow-origin":"*"}
        }));
      }
      if(url.startsWith("https://ipcdj-song-requests-staging.ipcdjofficial.workers.dev/")){
        const endpoint=new URL(url).pathname;
        return jsonResponse(endpoint==="/health"?
          {ok:true,environment:"staging",storageConfigured:true,
            intakeEnabled:false,notificationsEnabled:false,publicationEnabled:false}:
          {ok:true,songs:[]});
      }
      return originalFetch(input,init);
    };
  });
}

async function waitForLaunch(page){
  await page.waitForFunction(()=>!!window.IPCDJ_PREVIEW_ENGINE,null,{timeout:30000});
  await page.waitForFunction(()=>{
    const launch=document.getElementById("ipcdj-launch");
    if(!launch)return true;
    const css=getComputedStyle(launch);
    return launch.classList.contains("launch-idle")||
      (!document.documentElement.classList.contains("ipcdj-launch-active")&&
      (css.visibility==="hidden"||Number(css.opacity)<=.01));
  },null,{timeout:30000});
}

test("three newer and original songs share real Web Audio playback and crossfade state",async({page})=>{
  await installAudioFixture(page);
  await page.goto("/?engine-lock-fixture="+Date.now(),{waitUntil:"domcontentloaded"});
  await waitForLaunch(page);
  await page.locator("#tab-solicitudes").click();

  const first=page.locator('[data-preview-song-id="request-hablame-de-cerca-grupo-grace"] .preview-button');
  const barak=page.locator('[data-preview-song-id="request-bienvenido-espiritu-santo-barak"] .preview-button');
  await first.click();
  await expect.poll(()=>page.evaluate(()=>window.IPCDJ_PREVIEW_ENGINE.active().songId),
    {timeout:15000}).toBe("request-hablame-de-cerca-grupo-grace");
  await expect(first).toHaveAttribute("aria-label","Pausar adelanto");

  await barak.click();
  await expect.poll(()=>page.evaluate(()=>window.IPCDJ_PREVIEW_ENGINE.active().songId),
    {timeout:15000}).toBe("request-bienvenido-espiritu-santo-barak");
  await expect(barak).toHaveAttribute("aria-label","Pausar adelanto");
  await expect(first).toHaveAttribute("aria-label","Reproducir adelanto");

  await page.locator("#tab-vuelven-a-sonar").click();
  const conPoder=page.locator('[data-preview-song-id="retorno-con-poder-barak"] .preview-button');
  await conPoder.click();
  await expect.poll(()=>page.evaluate(()=>window.IPCDJ_PREVIEW_ENGINE.active().songId),
    {timeout:15000}).toBe("retorno-con-poder-barak");
  await expect(conPoder).toHaveAttribute("aria-label","Pausar adelanto");
  await expect(barak).toHaveAttribute("aria-label","Reproducir adelanto");

  const result=await page.evaluate(()=>({
    engine:window.IPCDJ_PREVIEW_ENGINE.name,
    playing:window.IPCDJ_PREVIEW_ENGINE.active().usingAudioBuffer,
    fetched:window.__IPCDJ_AUDIO_QA.audioFetches,
    lookedUp:window.__IPCDJ_AUDIO_QA.providerLookups
  }));
  expect(result.engine).toBe("webaudio");
  expect(result.playing).toBe(true);
  expect(result.fetched).toContain("1884087646");
  expect(result.fetched).toContain("9000101");
  expect(result.fetched).toContain("1777898241");
  expect(result.lookedUp).toContain("1783806472");

  await conPoder.click();
  await expect.poll(()=>page.evaluate(()=>window.IPCDJ_PREVIEW_ENGINE.active().playing),
    {timeout:6000}).toBe(false);
});
