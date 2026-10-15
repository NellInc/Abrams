// Render-completion verdict for serve.mjs, kept free of vite so it can be tested alone.
import {stat} from 'node:fs/promises';

// Success needs a numeric renderer result of 0 AND a non-empty MP4 written since startedAt.
// {status, reason} refuses the report; {status, result, receipt} finishes the run.
export async function verdict(body, video, startedAt){
  let parsed;
  try{parsed=JSON.parse(body);}catch{return {status:400,reason:'body is not JSON'};}
  if(typeof parsed?.result!=='number')return {status:400,reason:'result is not a number'};
  if(parsed.result!==0)return {status:200,result:parsed,receipt:false};
  const file=await stat(video).catch(()=>null);
  if(!file||file.size===0||file.mtimeMs<startedAt)return {status:200,result:{result:'missing-output',renderer:parsed.result,video},receipt:false};
  return {status:200,result:{...parsed,video,video_bytes:file.size},receipt:true};
}
