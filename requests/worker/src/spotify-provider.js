// IPCDJ Worship — isolated, SERVER-ONLY Spotify recording metadata lookup.
// No public HTTP route, no provider media download and no publishing rights.
import {spotifyId,evaluateSpotifyTrack} from "./spotify-verifier.js";
const TOKEN_URL="https://accounts.spotify.com/api/token";
const TRACK_URL="https://api.spotify.com/v1/tracks/";
const MAX_TOKEN_BYTES=16384,MAX_TRACK_BYTES=262144;
const credential=v=>typeof v==="string"&&/^[A-Za-z0-9_-]{16,128}$/.test(v);
export class SpotifyLookupError extends Error{
 constructor(code){super(code);this.name="SpotifyLookupError";this.code=code;}
}
async function requestJson(url,options,fetchImpl,limit){
 const controller=new AbortController();
 const timer=setTimeout(()=>controller.abort(),6000);
 try{
  const r=await fetchImpl(url,{...options,signal:controller.signal,redirect:"error"});
  if(!r||!Number.isInteger(r.status))throw new SpotifyLookupError("SPOTIFY_TRANSPORT_FAILED");
  if(r.status===404)return {notFound:true};
  if(!r.ok)throw new SpotifyLookupError(
   r.status===429?"SPOTIFY_QUOTA_OR_RATE_LIMITED":"SPOTIFY_PROVIDER_UNAVAILABLE");
  if(Number(r.headers?.get("content-length")||0)>limit)
   throw new SpotifyLookupError("SPOTIFY_RESPONSE_TOO_LARGE");
  // Bound ALL bytes read, including chunked responses without Content-Length.
  if(!r.body?.getReader)throw new SpotifyLookupError("SPOTIFY_RESPONSE_UNREADABLE");
  const reader=r.body.getReader(),chunks=[];let bytes=0;
  try{
   for(;;){
    const {value,done}=await reader.read();if(done)break;
    bytes+=value.byteLength;
    if(bytes>limit)throw new SpotifyLookupError("SPOTIFY_RESPONSE_TOO_LARGE");
    chunks.push(value);
   }
  }finally{await reader.cancel().catch(()=>{});reader.releaseLock();}
  const data=new Uint8Array(bytes);let pos=0;
  for(const chunk of chunks){data.set(chunk,pos);pos+=chunk.byteLength;}
  const parsed=JSON.parse(new TextDecoder("utf-8",{fatal:true}).decode(data));
  if(!parsed||typeof parsed!=="object"||Array.isArray(parsed))
   throw new SpotifyLookupError("SPOTIFY_INVALID_RESPONSE");
  return parsed;
 }catch(e){
  if(e instanceof SpotifyLookupError)throw e;
  // Do not log or propagate tokens, secrets, provider URLs or response bodies.
  throw new SpotifyLookupError("SPOTIFY_TRANSPORT_OR_JSON_FAILURE");
 }finally{clearTimeout(timer);}
}
export async function lookupSpotifyCandidate(request,env,{fetchImpl=fetch}={}){
 if(env?.APP_ENV!=="staging")throw new SpotifyLookupError("SPOTIFY_ENVIRONMENT_FORBIDDEN");
 const id=spotifyId(request?.link);
 if(!id)return {decision:"manual_review",reason:"INVALID_SPOTIFY_SOURCE",
  publicationEligible:false,match:null};
 if(!credential(env?.SPOTIFY_CLIENT_ID)||!credential(env?.SPOTIFY_CLIENT_SECRET))
  throw new SpotifyLookupError("SPOTIFY_NOT_CONFIGURED");
 const tokenData=await requestJson(TOKEN_URL,{
  method:"POST",
  headers:{Authorization:"Basic "+btoa(env.SPOTIFY_CLIENT_ID+":"+env.SPOTIFY_CLIENT_SECRET),
   "Content-Type":"application/x-www-form-urlencoded",Accept:"application/json"},
  body:"grant_type=client_credentials"
 },fetchImpl,MAX_TOKEN_BYTES);
 if(tokenData.notFound||typeof tokenData.access_token!=="string"||
    tokenData.access_token.length<8||tokenData.access_token.length>4096||
    String(tokenData.token_type||"").toLowerCase()!=="bearer")
  throw new SpotifyLookupError("SPOTIFY_INVALID_TOKEN_RESPONSE");
 const details=await requestJson(TRACK_URL+encodeURIComponent(id)+"?market=US",{
  method:"GET",headers:{Authorization:"Bearer "+tokenData.access_token,Accept:"application/json"}
 },fetchImpl,MAX_TRACK_BYTES);
 return evaluateSpotifyTrack(request,details.notFound?null:details);
}
