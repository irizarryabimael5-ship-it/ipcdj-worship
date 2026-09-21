const TZ = 'America/New_York';

export const NOTIFICATION_POLICY = Object.freeze({
  timezone: TZ,
  quietStartHour: 21,
  quietEndHour: 8,
  maxAutomaticPerSong: 6,
  schedulerWindowMinutes: 5,
  templateVersion: 1,
});

const TEMPLATE_SETS = Object.freeze({
  added: [
    ['Nueva en preparación', 'Ya está {title} en preparación. Empieza a familiarizarte con ella.'],
    ['Se añadió {title}', 'Ya puedes comenzar a escucharla y ubicar bien tu parte.'],
    ['Próxima canción: {title}', 'Empieza a conocerla desde ahora.'],
    ['{title} entra en preparación', 'Ve escuchándola con calma y conociendo su estructura.'],
    ['Nueva canción en camino', '{title} ya está en preparación. Empieza a darle oído.'],
    ['Tenemos nueva canción', '{title} ya está en la lista de preparación. Conócela desde ahora.'],
  ],
  learning_start: [
    ['Esta semana: {title}', 'Esta es la semana para escucharla y ubicar bien tu parte.'],
    ['Semana de aprendizaje', 'Toca trabajar {title}. Escúchala varias veces esta semana.'],
    ['A trabajar {title}', 'Esta semana enfócate en la estructura, letra y tu parte.'],
    ['Aprendizaje: {title}', 'Dale prioridad esta semana para llegar cómodo a la preparación final.'],
    ['Esta semana toca {title}', 'Escúchala con intención y asegúrate de conocer tu parte.'],
    ['Empezamos con {title}', 'Esta semana es para conocerla bien antes de afinar detalles.'],
  ],
  learning_mid: [
    ['Repaso de {title}', 'Si todavía no la tienes clara, hoy es buen momento para volverla a escuchar.'],
    ['¿Cómo vas con {title}?', 'Dale otro repaso y confirma que tienes clara tu parte.'],
    ['No dejes {title} para el final', 'Un repaso hoy hace la preparación final mucho más fácil.'],
    ['Seguimos con {title}', 'Vuelve a escucharla y revisa cualquier parte que todavía no esté clara.'],
    ['Mitad de semana', 'Dale otro repaso a {title} y confirma estructura y entradas.'],
    ['Un repaso más', 'Hoy viene bien escuchar {title} otra vez y revisar tu parte.'],
  ],
  final_start: [
    ['Preparación final', '{title} entra en su última semana. Estreno: {releaseDay}.'],
    ['Última semana de {title}', 'Ya no es solo escuchar: toca afinar detalles para {releaseDay}.'],
    ['Entramos en preparación final', 'Trabaja los detalles de {title}. Estreno: {releaseDay}.'],
    ['Recta final: {title}', 'Esta semana toca dejar tu parte lista para {releaseDay}.'],
    ['Esta es la semana final', 'Afina {title} y llega listo para el estreno {releaseDay}.'],
    ['{title}: preparación final', 'Revisa entradas y estructura. La estrenamos {releaseDay}.'],
  ],
  release_eve: [
    ['Mañana estrenamos {title}', 'Haz el último repaso hoy y llega listo.'],
    ['{title} es mañana', 'Último repaso y listo para el estreno.'],
    ['Mañana es el estreno', '{title} ya está aquí. Revisa tu parte una última vez.'],
    ['Último repaso de {title}', 'Mañana la estrenamos. Deja cualquier detalle resuelto hoy.'],
    ['Mañana toca {title}', 'Haz un repaso final y llega con seguridad.'],
    ['Estreno mañana', '{title}: último repaso hoy.'],
  ],
  release_day: [
    ['Hoy es el día', 'Estrenamos {title} a las {releaseTime}.'],
    ['Hoy estrenamos {title}', 'Nos vemos listos para el servicio de las {releaseTime}.'],
    ['Estreno de {title}', 'Es hoy a las {releaseTime}.'],
    ['{title} se estrena hoy', 'Servicio: {releaseTime}.'],
    ['Llegó el estreno', 'Hoy presentamos {title} a las {releaseTime}.'],
    ['Hoy toca {title}', 'Estreno a las {releaseTime}.'],
  ],
});

function partsInZone(epochMs, timeZone=TZ){
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone,
    year:'numeric', month:'2-digit', day:'2-digit',
    hour:'2-digit', minute:'2-digit', second:'2-digit',
    hourCycle:'h23'
  }).formatToParts(new Date(epochMs));
  const map = Object.fromEntries(parts.filter(p=>p.type!=='literal').map(p=>[p.type,p.value]));
  return {
    year:Number(map.year), month:Number(map.month), day:Number(map.day),
    hour:Number(map.hour), minute:Number(map.minute), second:Number(map.second)
  };
}

function offsetMsAt(epochMs, timeZone=TZ){
  const p=partsInZone(epochMs,timeZone);
  const asUTC=Date.UTC(p.year,p.month-1,p.day,p.hour,p.minute,p.second);
  return asUTC-Math.floor(epochMs/1000)*1000;
}

export function zonedEpoch(year,month,day,hour,minute,timeZone=TZ){
  let guess=Date.UTC(year,month-1,day,hour,minute,0);
  for(let i=0;i<4;i++){
    const next=Date.UTC(year,month-1,day,hour,minute,0)-offsetMsAt(guess,timeZone);
    if(Math.abs(next-guess)<1000){ guess=next; break; }
    guess=next;
  }
  return guess;
}

function datePartsFromIso(iso,timeZone=TZ){
  const epoch=Date.parse(iso);
  if(!Number.isFinite(epoch)) throw new Error('Invalid lifecycle timestamp: '+iso);
  return partsInZone(epoch,timeZone);
}

function addCalendarDays(parts,delta){
  const d=new Date(Date.UTC(parts.year,parts.month-1,parts.day+delta,12,0,0));
  return {year:d.getUTCFullYear(),month:d.getUTCMonth()+1,day:d.getUTCDate()};
}

function atLocalDateFromIso(iso,hour,minute,timeZone=TZ){
  const p=datePartsFromIso(iso,timeZone);
  return zonedEpoch(p.year,p.month,p.day,hour,minute,timeZone);
}

function atLocalDayOffsetFromIso(iso,dayDelta,hour,minute,timeZone=TZ){
  const base=datePartsFromIso(iso,timeZone);
  const p=addCalendarDays(base,dayDelta);
  return zonedEpoch(p.year,p.month,p.day,hour,minute,timeZone);
}

function nextAllowedDelivery(epochMs,timeZone=TZ){
  const p=partsInZone(epochMs,timeZone);
  if(p.hour>=NOTIFICATION_POLICY.quietStartHour){
    const n=addCalendarDays(p,1);
    return zonedEpoch(n.year,n.month,n.day,NOTIFICATION_POLICY.quietEndHour,12,timeZone);
  }
  if(p.hour<NOTIFICATION_POLICY.quietEndHour){
    return zonedEpoch(p.year,p.month,p.day,NOTIFICATION_POLICY.quietEndHour,12,timeZone);
  }
  return epochMs;
}

function midpointLocalEvening(startIso,endIso,timeZone=TZ){
  const a=Date.parse(startIso), b=Date.parse(endIso);
  if(!Number.isFinite(a)||!Number.isFinite(b)||b<=a)return null;
  const days=(b-a)/(24*60*60*1000);
  if(days<4)return null;
  const mid=a+(b-a)/2;
  const p=partsInZone(mid,timeZone);
  return zonedEpoch(p.year,p.month,p.day,18,12,timeZone);
}

function formatReleaseDay(iso,timeZone=TZ){
  return new Intl.DateTimeFormat('es-US',{
    timeZone, weekday:'long', day:'numeric', month:'long'
  }).format(new Date(Date.parse(iso)));
}

function formatReleaseTime(iso,timeZone=TZ){
  return new Intl.DateTimeFormat('es-US',{
    timeZone, hour:'numeric', minute:'2-digit', hour12:true
  }).format(new Date(Date.parse(iso))).replace(/\s/g,' ');
}

function hashString(value){
  let h=2166136261;
  for(let i=0;i<value.length;i++){
    h^=value.charCodeAt(i);
    h=Math.imul(h,16777619);
  }
  return h>>>0;
}

export function chooseVariantIndex(eventKey,kind,lastIndex=-1){
  const count=TEMPLATE_SETS[kind]?.length||1;
  let index=hashString(eventKey+'|v'+NOTIFICATION_POLICY.templateVersion)%count;
  if(count>1 && index===lastIndex) index=(index+1)%count;
  return index;
}

function interpolate(text,context){
  return String(text).replace(/\{(\w+)\}/g,(_,key)=>context[key]??'');
}

export function renderMessage(kind,song,eventKey,lastVariantIndex=-1){
  const set=TEMPLATE_SETS[kind];
  if(!set) throw new Error('Unknown notification kind: '+kind);

  const lastTitleIndex=lastVariantIndex>=0?Math.floor(lastVariantIndex/100):-1;
  const lastBodyIndex=lastVariantIndex>=0?lastVariantIndex%100:-1;
  const titleIndex=chooseVariantIndex(eventKey+'|title',kind,lastTitleIndex);
  const bodyIndex=chooseVariantIndex(eventKey+'|body',kind,lastBodyIndex);
  const ctx={
    title:song.title,
    releaseDay:formatReleaseDay(song.releaseAt),
    releaseTime:formatReleaseTime(song.releaseAt),
  };
  return {
    title:interpolate(set[titleIndex][0],ctx),
    body:interpolate(set[bodyIndex][1],ctx),
    variantIndex:titleIndex*100+bodyIndex,
    templateVersion:NOTIFICATION_POLICY.templateVersion,
  };
}

export function buildSongNotificationPlan(song,{nowMs=Date.now(),firstSeenAtMs=nowMs,timeZone=TZ}={}){
  const required=['id','title','activeFrom','learningStart','learningEnd','finalStart','releaseDayStartAt','releaseAt','introducedAt'];
  for(const key of required){ if(!song?.[key]) throw new Error('Missing '+key+' for notification planning'); }

  const entries=[];
  const add=(kind,scheduledAt)=>{
    if(!Number.isFinite(scheduledAt))return;
    const stamp=new Date(scheduledAt).toISOString();
    const key='auto:'+song.id+':'+kind+':'+stamp;
    entries.push({
      eventKey:key, kind, songId:song.id, scheduledAt:stamp,
      url:'/?song='+encodeURIComponent(song.id)+'&notice='+encodeURIComponent(kind),
    });
  };

  const activeAt=Date.parse(song.activeFrom);
  const learningAt=Date.parse(song.learningStart);
  const introducedAt=Date.parse(song.introducedAt);
  const announceBase=Math.max(firstSeenAtMs+2*60*1000,activeAt);

  // "Added" is a true first-entry notification, never a retroactive bootstrap message.
  // If push is enabled after a song's learning window already began, do not tell users
  // that the song was "just added"; the remaining future phase reminders are enough.
  if(firstSeenAtMs<learningAt && announceBase<introducedAt){
    add('added',nextAllowedDelivery(announceBase,timeZone));
  }

  add('learning_start',atLocalDateFromIso(song.learningStart,9,12,timeZone));
  const mid=midpointLocalEvening(song.learningStart,song.learningEnd,timeZone);
  if(mid)add('learning_mid',mid);
  add('final_start',atLocalDateFromIso(song.finalStart,9,12,timeZone));
  add('release_eve',atLocalDayOffsetFromIso(song.releaseDayStartAt,-1,18,12,timeZone));
  add('release_day',atLocalDateFromIso(song.releaseDayStartAt,8,12,timeZone));

  const releaseDayEnd=Date.parse(song.releaseDayEndAt||song.rolloverAt||song.introducedAt);
  const staleCutoff=nowMs-(NOTIFICATION_POLICY.schedulerWindowMinutes*60*1000);
  return entries
    // Never replay old lifecycle reminders during first deployment, a catalog resync,
    // or after the scheduler has been offline for a long period. A small grace window
    // keeps normal cron/deploy jitter reliable without creating a burst of stale pushes.
    .filter(event=>Date.parse(event.scheduledAt)>=staleCutoff)
    .filter(event=>Date.parse(event.scheduledAt)<introducedAt)
    .filter(event=>event.kind!=='release_day'||Date.parse(event.scheduledAt)<releaseDayEnd)
    .sort((a,b)=>Date.parse(a.scheduledAt)-Date.parse(b.scheduledAt))
    .slice(0,NOTIFICATION_POLICY.maxAutomaticPerSong);
}

export function templateKinds(){ return Object.freeze(Object.keys(TEMPLATE_SETS)); }
