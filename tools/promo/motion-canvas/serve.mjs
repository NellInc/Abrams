// Loopback-only asset renderer. It closes normally after the export completes.
// Run from a working folder that holds a copy of this motion-canvas/ directory:
//   (cd motion-canvas && npm ci) && node motion-canvas/serve.mjs
// then open the printed URL in a browser. The MP4 lands in motion-canvas/output/.
import {createServer} from 'vite';
import motionCanvasPackage from '@motion-canvas/vite-plugin';
import ffmpegPackage from '@motion-canvas/ffmpeg';
import {writeFile} from 'node:fs/promises';
import {verdict} from './completion.mjs';
const motionCanvas=motionCanvasPackage.default??motionCanvasPackage;
const ffmpeg=ffmpegPackage.default??ffmpegPackage;
const PORT=9328,ORIGIN=`http://127.0.0.1:${PORT}`;
// The exporter writes <output>/<settings.name>.mp4; render.html names it checkpoint-marker.
const VIDEO='./motion-canvas/output/checkpoint-marker.mp4';
const startedAt=Date.now();
let done;
const completion=new Promise(resolve => done=resolve);
const server=await createServer({configFile:false,root:process.cwd(),server:{host:'127.0.0.1',port:PORT,strictPort:true},
  plugins:[motionCanvas({project:'./motion-canvas/project.ts',output:'./motion-canvas/output'}),ffmpeg(),
    {name:'promo-completion',configureServer(server){server.middlewares.use('/promo-render-done',(req,res)=>{
      if(req.method!=='POST'){res.statusCode=405;res.end();return;}
      // Only the render page may report; other local origins are refused.
      if(req.headers.origin&&req.headers.origin!==ORIGIN){res.statusCode=403;res.end();return;}
      let body='';req.on('data',chunk=>body+=chunk);req.on('end',()=>{
        verdict(body,VIDEO,startedAt).then(async v=>{
          res.statusCode=v.status;res.end(v.status===200?'ok':v.reason);
          if(!v.result)return;
          if(v.receipt)await writeFile('./motion-canvas/render-receipt.json',JSON.stringify(v.result,null,2)+'\n');
          done(v.result);
        }).catch(error=>{if(!res.writableEnded){res.statusCode=500;res.end();}done({result:'receipt-error',message:String(error)});});
      });
    });}}]});
await server.listen();console.log(`PROMO_MOTION_SERVER_READY ${ORIGIN}/motion-canvas/render.html`);
const deadline=setTimeout(()=>done({result:'timeout'}),300000);
const result=await completion;clearTimeout(deadline);await server.close();
console.log('PROMO_MOTION_RESULT',JSON.stringify(result));process.exitCode=result.result===0?0:1;
