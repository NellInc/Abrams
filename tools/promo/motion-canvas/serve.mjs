// Loopback-only asset renderer. It closes normally after the export completes.
import {createServer} from 'vite';
import motionCanvasPackage from '@motion-canvas/vite-plugin';
import ffmpegPackage from '@motion-canvas/ffmpeg';
import {writeFile} from 'node:fs/promises';
const motionCanvas=motionCanvasPackage.default??motionCanvasPackage;
const ffmpeg=ffmpegPackage.default??ffmpegPackage;
let done;
const completion=new Promise(resolve => done=resolve);
const server=await createServer({configFile:false,root:process.cwd(),server:{host:'127.0.0.1',port:9328,strictPort:true},
  plugins:[motionCanvas({project:'./motion-canvas/project.ts',output:'./motion-canvas/output'}),ffmpeg(),
    {name:'promo-completion',configureServer(server){server.middlewares.use('/promo-render-done',(req,res)=>{
      if(req.method!=='POST'){res.statusCode=405;res.end();return;}
      let body='';req.on('data',chunk=>body+=chunk);req.on('end',async()=>{
        await writeFile('./motion-canvas/render-receipt.json',body);res.end('ok');done(JSON.parse(body));
      });
    });}}]});
await server.listen();console.log('PROMO_MOTION_SERVER_READY http://127.0.0.1:9328/motion-canvas/render.html');
const deadline=setTimeout(()=>done({result:'timeout'}),300000);
const result=await completion;clearTimeout(deadline);await server.close();
console.log('PROMO_MOTION_RESULT',JSON.stringify(result));process.exitCode=result.result===0?0:1;
