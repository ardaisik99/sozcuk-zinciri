/* Local, opt-in diagnostics: ?benchmark=1. No telemetry is sent anywhere. */
(() => {
  if (!new URLSearchParams(location.search).has('benchmark')) return;
  const stats = { start: performance.now(), callbacks: 0, callbackMs: 0,
    clears: 0, draws: 0, longTasks: 0, longTaskMs: 0 };
  const nativeRAF = window.requestAnimationFrame.bind(window);
  window.requestAnimationFrame = callback => nativeRAF(time => {
    const started = performance.now();
    callback(time);
    stats.callbackMs += performance.now() - started;
    stats.callbacks++;
  });
  const getContext = HTMLCanvasElement.prototype.getContext;
  const seen = new WeakSet();
  HTMLCanvasElement.prototype.getContext = function(...args) {
    const gl = getContext.apply(this,args);
    if (this.id === 'canvas' && gl && !seen.has(gl) && gl.clear) {
      seen.add(gl);
      for (const name of ['clear','drawElements','drawArrays','drawElementsInstanced','drawArraysInstanced']) {
        if (typeof gl[name] !== 'function') continue;
        const original = gl[name].bind(gl);
        gl[name] = (...params) => {
          if (name === 'clear') stats.clears++; else stats.draws++;
          return original(...params);
        };
      }
    }
    return gl;
  };
  try { new PerformanceObserver(list => {
    for (const task of list.getEntries()) { stats.longTasks++; stats.longTaskMs += task.duration; }
  }).observe({entryTypes:['longtask']}); } catch (_) { /* optional browser API */ }
  setInterval(() => {
    const canvas = document.getElementById('canvas');
    document.getElementById('stage').dataset.benchmark = JSON.stringify({
      elapsedMs: Math.round(performance.now()-stats.start),
      callbacks: stats.callbacks, callbackMs: +stats.callbackMs.toFixed(2),
      clears: stats.clears, draws: stats.draws, longTasks: stats.longTasks,
      longTaskMs: +stats.longTaskMs.toFixed(2), width: canvas.width, height: canvas.height
    });
  },1000);
})();
