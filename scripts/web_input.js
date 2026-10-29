/* Godot draws the UI. Transparent DOM inputs provide the device keyboard.
 * The same tile input survives every word change, preserving keyboard focus. */
(() => {
  const canvas = document.getElementById('canvas');
  const stage = document.getElementById('stage');
  const layer = document.getElementById('native-fields');
  window.wordInput = {
    changed: null, fields: new Map(),
    add(id, value, placeholder, max, kind = 'form') {
      if (this.fields.has(id)) return;
      const e = document.createElement('input');
      Object.assign(e, { className: 'word-input ' + kind, type: 'text', value,
        placeholder, maxLength: max, autocomplete: 'off', spellcheck: false,
        enterKeyHint: kind === 'tiles' ? 'next' : 'done' });
      e.dataset.fieldId = id;
      e.setAttribute('autocorrect', 'off');
      e.setAttribute('autocapitalize', 'off');
      e.setAttribute('aria-label', placeholder);
      e.addEventListener('input', event => {
        if (!event.isComposing) this.changed?.(id, e.value.normalize('NFC'), 'change');
      });
      e.addEventListener('compositionend', () => this.changed?.(id, e.value.normalize('NFC'), 'change'));
      e.addEventListener('focus', () => this.changed?.(id, e.value, 'focus'));
      e.addEventListener('blur', () => this.changed?.(id, e.value, 'blur'));
      e.addEventListener('keydown', event => {
        if (event.key === 'Enter' && !event.isComposing) {
          event.preventDefault(); this.changed?.(id, e.value, 'submit');
        }
      });
      e.addEventListener('wheel', event => {
        canvas.dispatchEvent(new WheelEvent('wheel', { deltaY: event.deltaY,
          deltaX: event.deltaX, deltaMode: event.deltaMode,
          clientX: event.clientX, clientY: event.clientY, bubbles: true }));
      }, { passive: true });
      let lastY = null;
      e.addEventListener('touchstart', event => {
        lastY = event.touches[0]?.clientY ?? null;
      }, { passive: true });
      e.addEventListener('touchmove', event => {
        const y = event.touches[0]?.clientY;
        if (lastY !== null && y !== undefined && Math.abs(lastY - y) > 3) {
          canvas.dispatchEvent(new WheelEvent('wheel', { deltaY: lastY - y,
            clientX: event.touches[0].clientX, clientY: y, bubbles: true }));
          lastY = y;
        }
      }, { passive: true });
      layer.appendChild(e); this.fields.set(id, e);
    },
    position(id, x, y, w, h) {
      const e = this.fields.get(id); if (!e) return;
      const rect = [x * stage.clientWidth, y * stage.clientHeight,
        w * stage.clientWidth, h * stage.clientHeight];
      const key = rect.map(v => v.toFixed(2)).join(',');
      if (e.dataset.rect === key) return;
      e.dataset.rect = key;
      Object.assign(e.style, { left: rect[0] + 'px', top: rect[1] + 'px',
        width: rect[2] + 'px', height: rect[3] + 'px',
        fontSize: Math.max(16, rect[3] * .345) + 'px' });
    },
    resetValue(id) {
      const e = this.fields.get(id); if (!e) return;
      e.value = '';
      if (document.activeElement === e) e.setSelectionRange(0, 0);
    },
    setValue(id, value) {
      const e = this.fields.get(id); if (!e) return;
      e.value = value;
      if (document.activeElement === e) e.setSelectionRange(value.length, value.length);
    },
    focused() { return document.activeElement?.dataset.fieldId || ''; },
    setScreen(id) {
      stage.dataset.screen = id;
      if (id !== 'game') { delete stage.dataset.level; delete stage.dataset.step; }
      window.framePacer?.wake(['win','party_results','countdown'].includes(id) ? 3400 : 1200);
    },
    setWord(level,step,previous,initial,count) {
      stage.dataset.level = level; stage.dataset.step = step;
      const description = previous+' ile bağlanan '+initial+' harfiyle başlayan '+count+' harfli sözcük';
      canvas.setAttribute('aria-label','Sözcük Zinciri — '+description);
      this.fields.forEach(e => { if (e.classList.contains('tiles')) e.setAttribute('aria-description',description); });
    },
    blur() { this.fields.forEach(e => e.blur()); },
    close() { this.fields.forEach(e => e.remove()); this.fields.clear(); }
  };
})();
