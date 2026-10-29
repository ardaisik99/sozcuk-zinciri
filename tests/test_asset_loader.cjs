const assert=require('node:assert/strict');
const {gzipSync}=require('node:zlib');
const {createHash,webcrypto,randomFillSync}=require('node:crypto');
const {createAssetFetch}=require('../scripts/asset_loader.js');
const hash=x=>createHash('sha256').update(x).digest('hex');
const raw=randomFillSync(Buffer.alloc(520031)),gz=gzipSync(raw);
const asset={name:'runtime',url:'runtime-test.wasm',gzip:'runtime-test.wasm.gz',size:raw.length,gzipSize:gz.length,hash:hash(raw),gzipHash:hash(gz),mime:'application/wasm'};
const baseURL='https://example.test/sozcuk-zinciri/';
function cacheStore() {
  const data=new Map();
  return {data,open:async()=>({match:async key=>data.get(key)?.clone(),put:async(key,response)=>data.set(key,response.clone()),delete:async key=>data.delete(key.url||key),keys:async()=>[...data.keys()].map(url=>({url}))})};
}
function server({range=true,failOnce=false,broken=false,bytes=gz}={}) {
  let calls=0,active=0,max=0,retried=false;
  return {get calls(){return calls;},get max(){return max;},fetch:async(url,init)=>{
    calls++; active++; max=Math.max(max,active);
    const [,a,b]=/^bytes=(\d+)-(\d+)$/.exec(init.headers.Range);
    const start=+a,end=+b;
    if(start>0) assert.equal(init.headers['If-Range'],'"stable"');
    await new Promise(resolve=>setTimeout(resolve,start%3));
    active--;
    if(!range) return new Response(bytes,{status:200});
    if(broken) return new Response('server error',{status:500});
    if(failOnce&&start>0&&!retried) {retried=true;return new Response(bytes.subarray(start,end-10),{status:206,headers:{'Content-Range':`bytes ${start}-${end}/${bytes.length}`}});}
    return new Response(bytes.subarray(start,end+1),{status:206,headers:{'Content-Range':`bytes ${start}-${end}/${bytes.length}`,ETag:'"stable"'}});
  }};
}
const make=(s,cache,extra={})=>createAssetFetch({assets:[asset],baseURL,originalFetch:s.fetch,cacheStorage:cache,crypto:webcrypto,chunkSize:65536,concurrency:4,...extra});
async function run() {
  const cache=cacheStore(),s=server(),progress=[];
  const loader=make(s,cache,{onProgress:(n,l,t,c)=>progress.push({l,t,c})});
  assert.deepEqual(Buffer.from(await(await loader(asset.url)).arrayBuffer()),raw,'parallel pieces decompress in exact order');
  assert.equal(s.max,4); assert.equal(s.calls,Math.ceil(gz.length/65536));
  assert.equal(cache.data.size,1,'only complete verified gzip is cached');
  for(let i=1;i<progress.length;i++) assert(progress[i].l>=progress[i-1].l);
  assert.equal(progress.at(-1).l,gz.length);
  const warm=server();let cacheHit=false;
  assert.deepEqual(Buffer.from(await(await make(warm,cache,{onProgress:(n,l,t,c)=>cacheHit=c})(asset.url)).arrayBuffer()),raw);
  assert(cacheHit);assert.equal(warm.calls,0,'warm load makes zero engine requests');
  const full=server({range:false});
  assert.deepEqual(Buffer.from(await(await make(full,cacheStore())(asset.url)).arrayBuffer()),raw);
  assert.equal(full.calls,1,'a Range-ignoring server only downloads once');
  const retry=server({failOnce:true});
  assert.deepEqual(Buffer.from(await(await make(retry,cacheStore())(asset.url)).arrayBuffer()),raw);
  assert.equal(retry.calls,Math.ceil(gz.length/65536)+1,'only the failed piece retries');
  const damaged=cacheStore();damaged.data.set(new URL(asset.gzip,baseURL).href,new Response('bad cache'));
  const repaired=server();
  assert.deepEqual(Buffer.from(await(await make(repaired,damaged)(asset.url)).arrayBuffer()),raw);
  assert(repaired.calls>0,'corrupt cache is replaced');
  const corrupt=Buffer.from(gz);corrupt[45]^=1;
  const corruptedStore=cacheStore();let errors=0;
  await assert.rejects(make(server({bytes:corrupt}),corruptedStore,{onError:()=>errors++})(asset.url),/bütünlüğü/);
  assert.equal(errors,1);assert.equal(corruptedStore.data.size,0,'failed integrity never poisons the cache');
  const broken=server({broken:true});errors=0;
  await assert.rejects(make(broken,cacheStore(),{attempts:2,onError:()=>errors++})(asset.url));
  assert.equal(broken.calls,2);assert.equal(errors,1,'bounded failures surface to the UI');
  const denied={open:async()=>{throw Error('storage denied');}};
  assert.deepEqual(Buffer.from(await(await make(server(),denied)(asset.url)).arrayBuffer()),raw);
  const fullCache={open:async()=>({match:async()=>null,put:async()=>{throw Error('quota');},keys:async()=>[]})};
  assert.deepEqual(Buffer.from(await(await make(server(),fullCache)(asset.url)).arrayBuffer()),raw);
  const ds=global.DecompressionStream;global.DecompressionStream=undefined;
  try {
    const plain=server({bytes:raw});
    assert.deepEqual(Buffer.from(await(await make(plain,cacheStore())(asset.url)).arrayBuffer()),raw,'raw fallback works without DecompressionStream');
  } finally {global.DecompressionStream=ds;}
  console.log('PASS: parallel byte order, bounded requests, retries, content integrity, cache reuse/repair, denied storage, Range fallback and legacy decompression fallback.');
}
run().catch(error=>{console.error(error);process.exitCode=1;});
