import {createApp} from './app.mjs';
const config={ownerKey:process.env.SCREENLINK_OWNER_KEY,livekitUrl:process.env.LIVEKIT_URL,apiKey:process.env.LIVEKIT_API_KEY,apiSecret:process.env.LIVEKIT_API_SECRET};
const server=createApp({config});
server.listen(Number(process.env.PORT||3000),process.env.HOST||'127.0.0.1',()=>console.log('ScreenLink pairing server ready.'));
process.on('SIGTERM',()=>server.close());
