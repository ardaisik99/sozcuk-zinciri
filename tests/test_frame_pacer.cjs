const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
let now = 0, serial = 0;
const jobs = new Map(), listeners = new Map();
function schedule(callback, delay) { const id=++serial; jobs.set(id,{at:now+delay,callback}); return id; }
const window = {
  requestAnimationFrame: callback => schedule(() => callback(now),(Math.floor(now/(1000/60))+1)*(1000/60)-now),
  cancelAnimationFrame: id => jobs.delete(id),
  addEventListener: (name,callback) => listeners.set(name,callback)
};
const document = {hidden:false,addEventListener:(name,callback)=>listeners.set(name,callback)};
vm.runInNewContext(fs.readFileSync('scripts/frame_pacer.js','utf8'),{
  window,document,performance:{now:()=>now},setTimeout:schedule,clearTimeout:id=>jobs.delete(id)
});
function advance(to) {
  for(let i=0;i<100000;i++) {
    let next=null;
    for(const [id,job] of jobs) if(job.at<=to&&(!next||job.at<next[1].at)) next=[id,job];
    if(!next) {now=to;return;}
    now=next[1].at;jobs.delete(next[0]);next[1].callback();
  }
  throw new Error('Scheduler did not yield');
}
const frames=[];
const tick=time=>{frames.push(time);window.requestAnimationFrame(tick);};
window.requestAnimationFrame(tick);
advance(3000);
const before=frames.length;
advance(5000);
assert(frames.length-before>=15&&frames.length-before<=21,'idle scheduling is about 10 Hz');
const wakeAt=now;
listeners.get('input')();
const mark=frames.length;
advance(now+20);
assert(frames.length>mark&&frames[mark]-wakeAt<=20,'input wakes without waiting for idle timeout');
const start=frames.length;
advance(now+500);
assert(frames.length-start>=24&&frames.length-start<=31,'active scheduling is at most 60 Hz');
let called=false;
const cancelled=window.requestAnimationFrame(()=>{called=true;});
window.cancelAnimationFrame(cancelled);
advance(now+200);
assert(!called,'cancelled frames never run');
console.log('PASS: browser pacing yields, idle 10 Hz, input wake, active 60 Hz and cancellation.');
