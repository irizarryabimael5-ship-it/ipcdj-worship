import fs from 'node:fs';

const START = {
  viernes: '<!-- WEEKLY_CURRENT_VIERNES_START -->',
  domingo: '<!-- WEEKLY_CURRENT_DOMINGO_START -->',
  history: '<!-- WEEKLY_HISTORY_START -->'
};
const END = {
  viernes: '<!-- WEEKLY_CURRENT_VIERNES_END -->',
  domingo: '<!-- WEEKLY_CURRENT_DOMINGO_END -->',
  history: '<!-- WEEKLY_HISTORY_END -->'
};

function replaceBetween(source,start,end,content){
  const a=source.indexOf(start);
  const b=source.indexOf(end,a+start.length);
  if(a<0||b<0)throw new Error('weekly rollover marker missing: '+start);
  return source.slice(0,a+start.length)+'\n'+content.trimEnd()+'\n          '+source.slice(b);
}

function between(source,start,end){
  const a=source.indexOf(start);
  const b=source.indexOf(end,a+start.length);
  if(a<0||b<0)throw new Error('weekly rollover marker missing: '+start);
  return source.slice(a+start.length,b).trim();
}

// Match by the stable data attribute rather than an exact class string.
// The real dashboard also carries weekly-event-active/campaign classes.
function dashboardTag(source){
  return source.match(/<div\b[^>]*\sdata-weekly-dashboard(?=[\s=>])[^>]*>/)?.[0]||'';
}

function attribute(source,name){
  const dashboard=dashboardTag(source);
  if(!dashboard)throw new Error('weekly dashboard marker missing');
  const match=dashboard.match(new RegExp('\\b'+name+'="([^"]*)"'));
  return match?.[1]||'';
}

function setDashboardAttribute(source,name,value){
  const dashboard=dashboardTag(source);
  if(!dashboard)throw new Error('weekly dashboard marker missing');
  return source.replace(dashboard,tag=>{
    const re=new RegExp('\\b'+name+'="[^"]*"');
    if(re.test(tag))return tag.replace(re,name+'="'+value+'"');
    return tag.slice(0,-1)+' '+name+'="'+value+'">';
  });
}

// Archived copies exclude YouTube playlist cards, iframes and links.
// The live weekly set and the original event template retain their playlists.
function stripArchivedPlaylistsMarkup(markup){
  return markup
    .replace(/\s*<section class="weekly-youtube-card">[\s\S]*?<\/section>\s*/g,'\n')
    .replace(/<a\b[^>]*href="[^"]*youtube\.com\/playlist[^"]*"[^>]*>[\s\S]*?<\/a>/gi,'')
    .replace(/Orden del servicio, playlist, recursos y detalles de ensayo\./g,
      'Orden del servicio, repertorio y recursos de ensayo.');
}

function archivePanel(block,key){
  let x=block;
  x=x.replace(
    '<section class="weekly-service-panel"',
    '<section class="weekly-service-panel weekly-history-service" data-weekly-history-service="'+key+'"'
  );
  x=x.replace(/\s+data-weekly-panel="[^"]*"/g,'');
  x=x.replace(/\s+role="tabpanel"/g,'');
  x=x.replace(/\s+hidden(?=[ >])/g,'');
  x=x.replace(/\s+id="[^"]*"/g,'');
  x=x.replace(/\s+aria-labelledby="[^"]*"/g,'');
  x=x.replace(/\s+aria-controls="[^"]*"/g,'');
  return stripArchivedPlaylistsMarkup(x);
}

function pendingPanel(key){
  const isFriday=key==='viernes';
  const label=isFriday?'Viernes':'Domingo';
  const hidden=isFriday?'':' hidden';
  return `          <section class="weekly-service-panel" id="weekly-panel-${key}" role="tabpanel" aria-labelledby="weekly-tab-${key}" data-weekly-panel="${key}"${hidden}>
            <div class="weekly-empty">
              <div class="weekly-empty-inner">
                <span class="weekly-service-kicker">${label}</span>
                <h3>Set pendiente</h3>
                <p>El nuevo worship set del ${key} aparecerá aquí cuando sea actualizado.</p>
              </div>
            </div>
          </section>`;
}

function cycleLabel(cycle){
  if(!/^\d{4}-\d{2}-\d{2}$/.test(cycle||''))return 'Semana anterior';
  const [year,month,day]=cycle.split('-').map(Number);
  const months=['ene','feb','mar','abr','may','jun','jul','ago','sept','oct','nov','dic'];
  return `Semana terminada · ${day} ${months[month-1]} ${year}`;
}

function setTabStatus(source,key,label){
  const re=new RegExp(
    '(<button class="weekly-service-tab"[^>]*data-weekly-service="'+key+'"[\\s\\S]*?<small>)[^<]*(</small>)'
  );
  if(!re.test(source))throw new Error('weekly tab missing: '+key);
  return source.replace(re,'$1'+label+'$2');
}

export function rolloverHtml(source,now=Date.now()){
  const state=attribute(source,'data-weekly-state');
  const cycle=attribute(source,'data-weekly-cycle');
  const rolloverAt=attribute(source,'data-weekly-rollover-at');
  const due=Date.parse(rolloverAt);
  const timestamp=Number(now);

  if(state!=='active')return {changed:false,source,reason:'inactive'};
  if(!Number.isFinite(due))throw new Error('invalid weekly rollover timestamp');
  if(!Number.isFinite(timestamp)||timestamp<due)return {changed:false,source,reason:'not-due'};

  const friday=between(source,START.viernes,END.viernes);
  const sunday=between(source,START.domingo,END.domingo);
  if(!friday.includes('data-weekly-panel="viernes"')||!sunday.includes('data-weekly-panel="domingo"')){
    throw new Error('active weekly panels missing');
  }

  // On the next standard Sunday, demote existing Semana anterior to history
  // rather than deleting Campaña GU (or any other prior special-event week).
  const prior=between(source,START.history,END.history);
  const firstOpen=prior.indexOf('<details class="weekly-history"');
  const firstClose=prior.indexOf('</details>',firstOpen);
  let preserved=prior;
  if(firstOpen>=0&&firstClose>=0){
    const first=prior.slice(firstOpen,firstClose+'</details>'.length);
    const oldCycle=first.match(/data-weekly-history-cycle="([^"]+)"/)?.[1]||"";
    const older=oldCycle
      ? first.replace('class="weekly-history"','class="weekly-history weekly-history-older"')
        .replace('data-weekly-history-body','data-weekly-older-history-body')
        .replace('<span>Semana anterior','<span>Historial')
        .replace(/data-weekly-archive-cycle="[^"]*"/,'data-weekly-archive-cycle="'+oldCycle+'"')
      : "";
    preserved=older+prior.slice(firstClose+'</details>'.length);
  }
  const history=`          <details class="weekly-history" data-weekly-archive-cycle="${cycle}">
            <summary>
              <span>Semana anterior</span>
              <small>${cycleLabel(cycle)}</small>
            </summary>
            <div class="weekly-history-body" data-weekly-history-body data-weekly-history-cycle="${cycle}">
              <div class="weekly-history-grid">
${archivePanel(friday,'viernes')}
${archivePanel(sunday,'domingo')}
              </div>
            </div>
          </details>
${preserved}`;

  let next=source;
  next=replaceBetween(next,START.viernes,END.viernes,pendingPanel('viernes'));
  next=replaceBetween(next,START.domingo,END.domingo,pendingPanel('domingo'));
  // Enforce the same policy on newly rolled sets and preserved older history.
  next=replaceBetween(next,START.history,END.history,stripArchivedPlaylistsMarkup(history));
  next=setDashboardAttribute(next,'data-weekly-state','rolled');
  next=setTabStatus(next,'viernes','Pendiente');
  next=setTabStatus(next,'domingo','Pendiente');
  next=next.replace(
    /(<span class="weekly-status" data-weekly-status>)[^<]*(<\/span>)/,
    '$1Nuevo set pendiente$2'
  );

  return {changed:true,source:next,reason:'rolled',cycle,rolloverAt};
}

function selfTest(){
  const fixture=`<div class="weekly-dashboard" data-weekly-dashboard data-weekly-state="active" data-weekly-cycle="2026-10-11" data-weekly-rollover-at="2026-10-11T15:00:00-04:00">
<span class="weekly-status" data-weekly-status>Viernes + Domingo actualizados</span>
<button class="weekly-service-tab" data-weekly-service="viernes"><small>Actualizado</small></button>
<button class="weekly-service-tab" data-weekly-service="domingo"><small>Actualizado</small></button>
${START.viernes}
<section class="weekly-service-panel" id="weekly-panel-viernes" role="tabpanel" aria-labelledby="weekly-tab-viernes" data-weekly-panel="viernes"><strong class="weekly-song-title" id="song-a">A</strong><section class="weekly-youtube-card"><div class="weekly-youtube-frame"><iframe src="https://www.youtube-nocookie.com/embed/videoseries?list=active-test"></iframe></div><a href="https://youtube.com/playlist?list=active-test">Abrir playlist en YouTube</a></section></section>
          ${END.viernes}
${START.domingo}
<section class="weekly-service-panel" id="weekly-panel-domingo" role="tabpanel" aria-labelledby="weekly-tab-domingo" data-weekly-panel="domingo" hidden><strong class="weekly-song-title" id="song-b">B</strong></section>
          ${END.domingo}
${START.history}
<details class="weekly-history"><div class="weekly-history-body" data-weekly-history-body></div></details>
          ${END.history}
</div>`;

  const before=rolloverHtml(fixture,Date.parse('2026-10-11T14:59:59-04:00'));
  if(before.changed)throw new Error('rollover occurred before 3 PM');
  if(!before.source.includes('youtube.com/playlist?list=active-test'))throw new Error('active weekly playlist lost before rollover');

  const at=rolloverHtml(fixture,Date.parse('2026-10-11T15:00:00-04:00'));
  if(!at.changed)throw new Error('rollover did not occur at 3 PM');
  if(!at.source.includes('data-weekly-state="rolled"'))throw new Error('state did not roll');
  if(!at.source.includes('data-weekly-history-cycle="2026-10-11"'))throw new Error('history cycle missing');
  if(!at.source.includes('data-weekly-history-service="viernes"'))throw new Error('Friday archive missing');
  if(!at.source.includes('data-weekly-history-service="domingo"'))throw new Error('Sunday archive missing');
  if(!at.source.includes('Nuevo set pendiente'))throw new Error('pending status missing');
  if((at.source.match(/id="song-[ab]"/g)||[]).length!==0)throw new Error('archived ids were not sanitized');
  if(at.source.includes('youtube.com/playlist?list=active-test')||at.source.includes('youtube-nocookie.com/embed/videoseries?list=active-test')||at.source.includes('weekly-youtube-card'))throw new Error('archived worship retains a playlist');

  const withCampaign=replaceBetween(fixture,START.history,END.history,`
<details class="weekly-history" data-weekly-archive-cycle="2026-10-11">
  <summary><span>Semana anterior · Campaña GU 2026</span></summary>
  <div data-weekly-history-body data-weekly-history-cycle="2026-10-11">
    <div data-weekly-special-archive-grid="campana-gu-2026">Archived Fri/Sat/Sun event</div>
  </div>
</details>
<details class="weekly-history weekly-history-older" data-weekly-archive-cycle="2026-10-04">
  <div data-weekly-older-history-body data-weekly-history-cycle="2026-10-04">Older Friday/Sunday<section class="weekly-youtube-card"><iframe src="https://www.youtube-nocookie.com/embed/videoseries?list=old-history"></iframe></section></div>
</details>`);
  const afterCampaign=rolloverHtml(withCampaign,Date.parse('2026-10-11T15:00:00-04:00'));
  if(!afterCampaign.changed||!afterCampaign.source.includes('Archived Fri/Sat/Sun event')||
     !afterCampaign.source.includes('Older Friday/Sunday')||
     !afterCampaign.source.includes('data-weekly-older-history-body')){
    throw new Error('weekly rollover lost historic event or older week');
  }
  if(afterCampaign.source.includes('list=old-history')||afterCampaign.source.includes('weekly-youtube-card'))throw new Error('older history retained YouTube playlist');

  const twice=rolloverHtml(at.source,Date.parse('2026-10-11T16:00:00-04:00'));
  if(twice.changed)throw new Error('rolled week archived twice');

  // Regression: production/staging use extra state-specific CSS classes, which
  // previously caused exact-class matching to silently return "inactive".
  const decorated=fixture.replace('class="weekly-dashboard"','class="weekly-dashboard weekly-event-active"');
  const decoratedResult=rolloverHtml(decorated,Date.parse('2026-10-11T15:00:00-04:00'));
  if(!decoratedResult.changed)throw new Error('decorated weekly dashboard failed to roll');
  if(!decoratedResult.source.includes('class="weekly-dashboard weekly-event-active"')){
    throw new Error('extra dashboard CSS class was lost');
  }
  if(!decoratedResult.source.includes('data-weekly-state="rolled"')){
    throw new Error('decorated dashboard state not updated');
  }
  const twiceDecorated=rolloverHtml(decoratedResult.source,Date.parse('2026-10-11T16:00:00-04:00'));
  if(twiceDecorated.changed)throw new Error('decorated week archived twice');
}

if(process.argv.includes('--self-test')){
  selfTest();
  console.log('weekly rollover self-test passed');
}else if(import.meta.url===new URL('file://'+process.argv[1]).href){
  const file=process.argv[2]||'index.html';
  const source=fs.readFileSync(file,'utf8');
  const nowValue=process.env.IPCDJ_ROLLOVER_NOW;
  const now=nowValue ? Date.parse(nowValue) : Date.now();
  const result=rolloverHtml(source,now);
  if(result.changed){
    fs.writeFileSync(file,result.source);
    console.log(`Rolled Worship semanal cycle ${result.cycle} into Semana anterior.`);
  }else{
    console.log(`No weekly rollover needed (${result.reason}).`);
  }
}
