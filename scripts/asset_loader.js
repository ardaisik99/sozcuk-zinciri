/* Bounded parallel downloads + content-verified persistent cache.
 * Complete compressed files are cached; partial/failed downloads never are. */
(() => {
  const hex = bytes => [...new Uint8Array(bytes)].map(x => x.toString(16).padStart(2,'0')).join('');
  function chooseTransport(asset) {
    for (const [field,encoding] of [['brotli','brotli'],['gzip','gzip']]) {
      if (!asset[field] || typeof DecompressionStream!=='function') continue;
      try {new DecompressionStream(encoding);return {url:asset[field],size:asset[field+'Size'],hash:asset[field+'Hash'],encoding};} catch (_) { /* use the next native format */ }
    }
    return {url:asset.url,size:asset.size,hash:asset.hash,encoding:''};
  }
  function createAssetFetch({assets, baseURL, originalFetch = globalThis.fetch.bind(globalThis),
    cacheStorage = globalThis.caches, crypto = globalThis.crypto,
    chunkSize = 256 * 1024, concurrency = 4, attempts = 3, timeoutMs = 20000,
    onProgress = () => {}, onError = () => {}}) {
    const cacheReady = cacheStorage
      ? Promise.resolve().then(()=>cacheStorage.open('sozcuk-zinciri-assets-v1')).catch(() => null) : Promise.resolve(null);
    const downloading = new Map();
    const absolute = url => new URL(url,baseURL).href;
    async function valid(data,size,hash) {
      return data.byteLength === size && (!hash || hex(await crypto.subtle.digest('SHA-256',data)) === hash);
    }
    async function getFile(asset, transport) {
      const url = absolute(transport.url),size = transport.size,hash = transport.hash;
      const cache = await cacheReady;
      const cached = cache ? await cache.match(url).catch(() => null) : null;
      if (cached) {
        try {
          const data = new Uint8Array(await cached.arrayBuffer());
          if (await valid(data,size,hash)) {
            onProgress(asset.name,size,size,true,transport.encoding); return data;
          }
        } catch (_) { /* damaged cache is replaced by a verified download */ }
        await cache.delete(url).catch(() => {});
      }
      let loaded = 0, stopped = false;
      const controllers = new Set();
      const stop = () => { stopped = true; for (const c of controllers) c.abort(); };
      onProgress(asset.name,0,size,false,transport.encoding);
      async function part(start,end,etag = '') {
        for (let attempt = 0; attempt < attempts; attempt++) {
          if (stopped) throw new Error('İndirme durduruldu.');
          const controller = new AbortController(); controllers.add(controller);
          const timer = setTimeout(() => controller.abort(),timeoutMs);
          try {
            const headers = {Range:`bytes=${start}-${end}`};
            if (etag) headers['If-Range'] = etag;
            const response = await originalFetch(url,{headers,signal:controller.signal});
            const data = new Uint8Array(await response.arrayBuffer());
            // Some local/static servers ignore Range. Only the first request
            // may return the whole file; never start duplicate full downloads.
            if (response.status === 200 && start === 0) {
              if (data.length !== size) throw new Error('Dosya eksik indirildi.');
              loaded = size; onProgress(asset.name,loaded,size,false,transport.encoding);
              return {data,whole:true};
            }
            const expected = `bytes ${start}-${end}/${size}`;
            if (response.status !== 206 || response.headers.get('content-range') !== expected || data.length !== end-start+1) {
              throw new Error('İndirme parçası doğrulanamadı.');
            }
            if (etag && response.headers.get('etag') && response.headers.get('etag') !== etag) throw new Error('Dosya sürümü değişti.');
            loaded += data.length; onProgress(asset.name,loaded,size,false,transport.encoding);
            return {data,etag:response.headers.get('etag') || ''};
          } catch (error) {
            if (stopped || attempt+1 === attempts) throw error;
            await new Promise(resolve => setTimeout(resolve,200*(attempt+1)));
          } finally { clearTimeout(timer); controllers.delete(controller); }
        }
      }
      try {
        const first = await part(0,Math.min(chunkSize,size)-1);
        let data = first.data;
        if (!first.whole && data.length < size) {
          data = new Uint8Array(size); data.set(first.data);
          let offset = first.data.length;
          await Promise.all(Array.from({length:Math.min(concurrency,Math.ceil((size-offset)/chunkSize))},async () => {
            while (offset < size && !stopped) {
              const start = offset; offset += chunkSize;
              const result = await part(start,Math.min(start+chunkSize,size)-1,first.etag);
              data.set(result.data,start);
            }
          }));
        }
        if (!await valid(data,size,hash)) throw new Error('İndirilen dosyanın bütünlüğü doğrulanamadı.');
        // Storage is optional: quota/private-mode failures cannot block play.
        if (cache) {
          await cache.put(url,new Response(data,{headers:{'Content-Type':'application/octet-stream'}})).catch(() => {});
          // Retain the current and previous content version for each asset.
          const prefix=new URL(asset.name==='runtime'?'runtime-':'game-',baseURL).href;
          const family=(await cache.keys().catch(()=>[])).filter(key=>key.url.startsWith(prefix));
          for (const old of family.slice(0,-2)) await cache.delete(old).catch(()=>{});
        }
        return data;
      } catch (error) { stop(); throw error; }
    }
    return async function(input,init) {
      const requested = absolute(typeof input === 'string' ? input : input.url || String(input));
      const asset = assets.find(x => absolute(x.url) === requested);
      if (!asset) return originalFetch(input,init);
      try {
        const transport = chooseTransport(asset);
        if (!downloading.has(requested)) {
          const pending = getFile(asset,transport);
          downloading.set(requested,pending);
          pending.catch(() => downloading.delete(requested));
        }
        const data = await downloading.get(requested);
        downloading.delete(requested);
        const body = new Response(data).body;
        return new Response(transport.encoding ? body.pipeThrough(new DecompressionStream(transport.encoding)) : body,
          {headers:{'Content-Type':asset.mime,'Content-Length':String(asset.size)}});
      } catch (error) { onError(error); throw error; }
    };
  }
  globalThis.SozcukAssetLoader = {createAssetFetch,chooseTransport};
  if (typeof module !== 'undefined' && module.exports) module.exports = {createAssetFetch,chooseTransport};
})();
