(() => {
  const {config,assets} = window.SozcukBuild;
  const stage=document.getElementById('stage'),canvas=document.getElementById('canvas');
  const status=document.getElementById('status'),detail=document.getElementById('detail'),fill=document.getElementById('fill');
  config.args=(config.args||[]).concat(['--audio-driver','Dummy']);
  config.canvasResizePolicy=0;
  let failed=false;
  function fail(error) {
    if (failed) return; failed=true; stage.dataset.loadState='error';
    document.getElementById('error').hidden=false;
    document.getElementById('error').textContent='İndirme tamamlanamadı. Yeniden deneyebilirsin.';
    document.getElementById('retry').hidden=false;
    detail.textContent='Bağlantı yeniden kurulmayı bekliyor.';
    console.error(error);
  }
  const progress=new Map();
  window.fetch=SozcukAssetLoader.createAssetFetch({assets,baseURL:location.href,onError:fail,
    onProgress:(name,loaded,total,cached)=>{
      progress.set(name,{loaded,total,cached});
      const all=[...progress.values()];
      const expected=assets.reduce((n,a)=>n+(typeof DecompressionStream==='function' ? a.gzipSize : a.size),0);
      const received=all.reduce((n,a)=>n+a.loaded,0);
      const percent=Math.min(94,Math.round(received/expected*94));
      fill.style.width=percent+'%';
      detail.textContent=percent>=94?'Oyun açılıyor…':'Yükleniyor… %'+percent;
      stage.dataset.loadProgress=JSON.stringify(Object.fromEntries(progress));
    }});
  function fitCanvas(){const dpr=Math.min(window.devicePixelRatio||1,2),w=Math.round(stage.clientWidth*dpr),h=Math.round(stage.clientHeight*dpr);if(canvas.width!==w)canvas.width=w;if(canvas.height!==h)canvas.height=h;}
  fitCanvas();new ResizeObserver(fitCanvas).observe(stage);
  stage.dataset.loadState='loading';
  if(typeof Engine==='undefined') { fail(new Error('Motor başlatıcısı indirilemedi.')); return; }
  const engine=new Engine(config);
  if(Engine.getMissingFeatures({threads:false}).length) { fail(new Error('WebGL 2 ve WebAssembly gerekiyor.')); return; }
  engine.startGame().then(()=>{
    // The first playable screen signals ready from Godot. Engine.startGame()
    // alone resolves while the one-frame loading screen is still visible.
    stage.dataset.engineStartedMs=Math.round(performance.now());
    const ready=()=>{
      if (!stage.dataset.screen || stage.dataset.screen==='loading') return false;
      stage.dataset.readyMs=Math.round(performance.now()); stage.dataset.loadState='ready';
      status.remove();canvas.focus();return true;
    };
    if (!ready()) {
      const watch=new MutationObserver(()=>{if(ready())watch.disconnect();});
      watch.observe(stage,{attributes:true,attributeFilter:['data-screen']});
      setTimeout(()=>{watch.disconnect();if(stage.dataset.loadState!=='ready')fail(new Error('İlk ekran açılamadı.'));},12000);
    }
  }).catch(fail);
  document.addEventListener('visibilitychange',()=>{if(document.hidden&&document.activeElement?.tagName==='INPUT')document.activeElement.blur();});
})();
