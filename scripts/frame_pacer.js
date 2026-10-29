/* Timers yield to the browser: no WASM sleep/busy wait. Idle: 10 lightweight
 * logic updates/sec, unchanged GPU frames skipped. Interaction: up to 60 Hz. */
(() => {
  const raf = window.requestAnimationFrame.bind(window);
  const cancelRAF = window.cancelAnimationFrame.bind(window);
  const waiting = new Map();
  let serial = 0, lastFrame = 0, activeUntil = performance.now()+1800;
  function queue(task, immediate = false) {
    const now = performance.now();
    const interval = now < activeUntil ? 1000/60 : 100;
    // Hand the callback to RAF just before its intended presentation slot;
    // waiting until that slot would accidentally halve 60 Hz to 30 Hz.
    const delay = immediate ? 0 : Math.max(0,lastFrame+interval-now-1);
    task.timer = setTimeout(() => {
      task.timer = null;
      task.frame = raf(time => {
        waiting.delete(task.id); lastFrame = time; task.callback(time);
      });
    },delay);
  }
  window.requestAnimationFrame = callback => {
    const task = {id:--serial,callback,timer:null,frame:null};
    waiting.set(task.id,task); queue(task); return task.id;
  };
  window.cancelAnimationFrame = id => {
    const task = waiting.get(id);
    if (!task) { if (id >= 0) cancelRAF(id); return; }
    if (task.timer !== null) clearTimeout(task.timer);
    if (task.frame !== null) cancelRAF(task.frame);
    waiting.delete(id);
  };
  function wake(ms = 1200) {
    activeUntil = Math.max(activeUntil,performance.now()+ms);
    for (const task of waiting.values()) {
      if (task.timer !== null) { clearTimeout(task.timer); queue(task,true); }
    }
  }
  window.framePacer = {wake};
  for (const name of ['pointerdown','pointermove','keydown','input','wheel','touchmove','resize','focus']) {
    window.addEventListener(name,() => wake(),{capture:true,passive:true});
  }
  document.addEventListener('visibilitychange',() => { if (!document.hidden) wake(); });
})();
