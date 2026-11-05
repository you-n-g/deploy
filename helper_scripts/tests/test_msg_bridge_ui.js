// Run with: node --test helper_scripts/tests/test_msg_bridge_ui.js
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { webcrypto } = require('node:crypto');

const source = fs.readFileSync(path.join(__dirname, '../bin/msg-bridge'), 'utf8')
  .match(/WEB_SCRIPT = r"""([\s\S]*?)"""/)[1];

function element(tagName = 'div') {
  return {
    tagName, style: {}, scrollHeight: 96, value: '', hidden: true, disabled: false, dataset: {}, children: [], handlers: {}, listenerOptions: {},
    addEventListener(event, handler, options) { this.handlers[event] = handler; this.listenerOptions[event] = options; },
    focus() {}, scrollIntoView() {},
    querySelector(selector) {
      for (const child of this.children) {
        if (selector.startsWith('.') ? (child.className || '').split(' ').includes(selector.slice(1)) : child.tagName === selector) return child;
        const found = child.querySelector(selector);
        if (found.tagName) return found;
      }
      return { disabled: false };
    },
    querySelectorAll(selector) { return this.children.flatMap((child) => [...(selector.split(', ').includes(child.tagName) ? [child] : []), ...child.querySelectorAll(selector)]); },
    replaceChildren(...children) { this.children = []; this.append(...children); },
    append(...children) { children.forEach((child) => { child.parent = this; this.children.push(child); }); },
    insertBefore(child, before) {
      if (child.parent) child.parent.children = child.parent.children.filter((item) => item !== child);
      child.parent = this;
      const index = before === null ? this.children.length : this.children.indexOf(before);
      this.children.splice(index, 0, child);
    },
    getBoundingClientRect() { return { top: 0, bottom: 400, height: 400, left: 0, right: 400 }; },
    setPointerCapture() {},
  };
}

function favoriteBox(browser, groupId = 0) {
  return browser.elements['#favorite-list'].children.find((box) => box.dataset.groupId === String(groupId));
}
function favoriteContainer(browser, groupId = 0) { return favoriteBox(browser, groupId).querySelector('.favorite-group-items'); }
function favoriteRows(browser) { return browser.elements['#favorite-list'].children.flatMap((box) => box.querySelector('.favorite-group-items').children); }

function response(body, status = 200) {
  if (Array.isArray(body.favorites)) body.favorites = body.favorites.map((entry) => ({ group_id: 0, group_position: null, ...entry }));
  if (typeof body.id === 'number' && 'content' in body) body = { group_id: 0, group_position: null, ...body };
  if (body.favorite_groups && !body.favorite_group_order) body.favorite_group_order = [0, ...body.favorite_groups.map((group) => group.id)];
  return { ok: status < 400, status, json: async () => body, text: async () => String(body) };
}

async function page(exchange, historyHangs = false, initialState = { authenticated: true, messages: [], saved: [] }) {
  initialState = { favorites: [], favorite_groups: [], ...initialState };
  initialState.favorite_group_order = initialState.favorite_group_order || [0, ...initialState.favorite_groups.map((group) => group.id)];
  initialState.favorites = initialState.favorites.map((entry) => ({ group_id: 0, group_position: null, ...entry }));
  const elements = {};
  for (const name of ['sender', 'login', 'account', 'logout', 'password', 'message', 'status',
    'workspace', 'history-list', 'history-status', 'refresh-history', 'send-draft', 'send-submit', 'send-left', 'save-message', 'saved-list', 'favorite-list', 'favorite-new-group', 'favorite-new-open', 'favorite-new-editor', 'favorite-new-name', 'favorite-new-save', 'favorite-new-cancel', 'initial-state']) {
    elements[`#${name}`] = element();
  }
  elements['#initial-state'].content = { textContent: JSON.stringify(initialState) };
  const calls = [];
  const holdTimers = new Map();
  let historyLoads = 0;
  vm.runInNewContext(source, {
    document: { querySelector: (name) => elements[name], createElement: element },
    crypto: webcrypto, AbortSignal, TypeError,
    window: { innerHeight: 800, scrollBy() {}, addEventListener() {} },
    setTimeout: (resolve, delay) => {
      if (delay !== 400) return setImmediate(resolve);
      const id = {};
      holdTimers.set(id, resolve);
      return id;
    },
    clearTimeout: (id) => { if (!holdTimers.delete(id)) clearImmediate(id); },
    fetch: async (url, options) => {
      calls.push({ url, options });
      if (url.endsWith('/session')) return response({ authenticated: true });
      if (url.endsWith('/messages') && options.method === 'GET') {
        if (++historyLoads > 0 && historyHangs) return new Promise(() => {});
        return response({ messages: [], saved: [], favorites: [], favorite_groups: [] });
      }
      return exchange(url, options);
    },
  });
  await new Promise(setImmediate);
  return {
    elements, calls,
    hold() {
      const callbacks = [...holdTimers.values()];
      holdTimers.clear();
      callbacks.forEach((callback) => callback());
    },
    async send(content) {
      elements['#message'].value = content;
      await elements['#sender'].handlers.submit({ preventDefault() {} });
    },
  };
}

test('first screen restores login and history without additional network requests', async () => {
  const browser = await page(() => { throw new Error('First screen must not fetch'); }, false, {
    authenticated: true, saved: [], messages: [{ id: 1, received_at: '2026-10-18T00:00:00Z', content: '<private history>' }],
  });
  assert.equal(browser.calls.length, 0);
  assert.equal(browser.elements['#workspace'].hidden, false);
  assert.equal(browser.elements['#login'].hidden, true);
  assert.equal(browser.elements['#history-list'].children[0].children[1].textContent, '<private history>');
});

test('anonymous first screen shows login without fetching private history', async () => {
  const browser = await page(() => { throw new Error('Anonymous page must not fetch'); }, false, { authenticated: false });
  assert.equal(browser.calls.length, 0);
  assert.equal(browser.elements['#workspace'].hidden, true);
  assert.equal(browser.elements['#login'].hidden, false);
});

test('login confirms browser cookie with an authenticated request before showing the sender', async () => {
  const browser = await page(async (url) => {
    assert.ok(url.endsWith('/login'));
    return response({ authenticated: true });
  }, false, { authenticated: false });
  browser.elements['#password'].value = 'password';
  await browser.elements['#login'].handlers.submit({ preventDefault() {} });
  assert.deepEqual(browser.calls.map((call) => call.url), ['./api/login', './api/messages']);
  assert.equal(browser.elements['#login'].hidden, true);
  assert.equal(browser.elements['#workspace'].hidden, false);
  assert.equal(browser.elements['#password'].value, '');
});

test('lost success response is confirmed by receipt; slow history never locks sending', async () => {
  let requestId;
  const browser = await page(async (url, options) => {
    if (options.method === 'POST') {
      requestId = JSON.parse(options.body).request_id;
      assert.equal(options.headers['X-Request-ID'], requestId);
      const success = response({});
      success.json = async () => { throw new TypeError('response connection closed'); };
      return success;
    }
    assert.ok(url.endsWith(`/requests/${requestId}`));
    return response({ status: 'sent', receivers: 1 });
  }, true);
  await browser.send('already delivered');
  assert.match(requestId, /^[0-9a-f]{32}$/);
  assert.equal(browser.calls.filter((call) => call.options.method === 'POST').length, 1);
  assert.match(browser.elements['#status'].textContent, /已发送到 1/);
  assert.equal(browser.elements['#message'].value, '');
  assert.equal(browser.elements['#message'].readOnly, false);
  assert.equal(browser.elements['#send-submit'].disabled, false);
  assert.equal(browser.elements['#send-draft'].disabled, false);
});

test('unconfirmed send retains its request id when the user retries the same content', async () => {
  const ids = [];
  const browser = await page(async (url, options) => {
    if (options.method === 'POST') {
      ids.push(JSON.parse(options.body).request_id);
      if (ids.length > 1) return response({ status: 'sent', receivers: 1 });
    }
    throw new TypeError('network unavailable');
  });
  await browser.send('keep this draft');
  assert.equal(browser.elements['#message'].value, 'keep this draft');
  assert.match(browser.elements['#status'].textContent, /发送结果暂未确认/);
  assert.equal(browser.calls.filter((call) => call.url.includes('/requests/')).length, 3);
  await browser.send('keep this draft');
  assert.equal(ids.length, 2);
  assert.equal(ids[0], ids[1]);
  assert.equal(browser.elements['#message'].value, '');
});

test('pending receipt is polled until sent without posting a second message', async () => {
  let polls = 0;
  const browser = await page(async (url, options) => {
    if (options.method === 'POST') return response({ status: 'pending' }, 202);
    return response(++polls === 1 ? { status: 'pending' } : { status: 'sent', receivers: 1 });
  });
  await browser.send('slow transfer');
  assert.equal(polls, 2);
  assert.equal(browser.calls.filter((call) => call.options.method === 'POST').length, 1);
  assert.match(browser.elements['#status'].textContent, /已发送到 1/);
});

test('server 5xx after delivery is resolved through the saved receipt', async () => {
  const browser = await page(async (url, options) => options.method === 'POST'
    ? response('upstream failed', 502) : response({ status: 'sent', receivers: 0 }));
  await browser.send('archived offline');
  assert.match(browser.elements['#status'].textContent, /没有接收端在线/);
  assert.equal(browser.elements['#message'].value, '');
});

test('saving creates a highlighted entry without sending a message', async () => {
  const browser = await page(async (url, options) => {
    assert.ok(url.endsWith('/saved'));
    const payload = JSON.parse(options.body);
    return response({ id: payload.request_id, created_at: '2026-10-19T00:00:00Z', content: payload.message });
  });
  browser.elements['#message'].value = '<saved text>\n第二行';
  await browser.elements['#save-message'].handlers.click();
  assert.equal(browser.calls.filter((call) => call.options.method === 'POST').length, 1);
  const entry = browser.elements['#saved-list'].children[0].children[0];
  assert.equal(entry.className, 'history-item saved-item');
  assert.equal(entry.children[1].textContent, '<saved text>\n第二行');
  assert.equal(browser.elements['#message'].value, '');
  assert.match(browser.elements['#status'].textContent, /已暂存/);
});

test('saved message uses its durable request id and becomes ordinary after receipt confirmation', async () => {
  const id = 'c'.repeat(32);
  const browser = await page(async (url, options) => {
    if (options.method === 'POST') {
      assert.deepEqual(JSON.parse(options.body), { message: 'later', submit: true, request_id: id });
      throw new TypeError('success response lost');
    }
    assert.ok(url.endsWith(`/requests/${id}`));
    return response({ status: 'sent', receivers: 1 });
  }, true, { authenticated: true, messages: [], saved: [{ id, content: 'later' }] });
  browser.elements['#message'].value = 'keep current editing';
  const item = browser.elements['#saved-list'].children[0].children[0];
  const sending = item.handlers.click({detail: 1});
  await item.handlers.click({detail: 1});
  await sending;
  assert.equal(browser.calls.filter((call) => call.options.method === 'POST').length, 1);
  assert.equal(browser.elements['#saved-list'].children.length, 0);
  assert.equal(browser.elements['#message'].value, 'keep current editing');
  assert.equal(browser.elements['#history-list'].children[0].children[1].textContent, 'later');
});

test('rejected send leaves the saved entry available', async () => {
  const browser = await page(async () => response('send rejected', 409), false, {
    authenticated: true, messages: [], saved: [{ id: 'd'.repeat(32), content: 'retain this' }],
  });
  await browser.elements['#saved-list'].children[0].children[0].handlers.click({detail: 1});
  assert.equal(browser.elements['#saved-list'].children.length, 1);
  assert.equal(browser.elements['#saved-list'].children[0].children[0].disabled, false);
  assert.match(browser.elements['#status'].textContent, /send rejected/);
});

test('delete button removes only the saved entry and preserves the input', async () => {
  const id = 'e'.repeat(32);
  const browser = await page(async (url, options) => {
    assert.equal(options.method, 'DELETE');
    assert.ok(url.endsWith(`/saved/${id}`));
    return response({ deleted: id });
  }, false, { authenticated: true, messages: [], saved: [{ id, content: 'discard' }] });
  browser.elements['#message'].value = 'still editing';
  await browser.elements['#saved-list'].children[0].children[1].handlers.click();
  assert.equal(browser.elements['#saved-list'].children.length, 0);
  assert.equal(browser.elements['#message'].value, 'still editing');
  assert.equal(browser.calls.length, 1);
});

test('failed deletion keeps the card and permits an idempotent retry', async () => {
  let attempts = 0;
  const browser = await page(async (url, options) => {
    assert.equal(options.method, 'DELETE');
    if (++attempts === 1) throw new TypeError('response lost');
    return response({ deleted: 'e'.repeat(32) });
  }, false, { authenticated: true, messages: [], saved: [{ id: 'e'.repeat(32), content: 'discard' }] });
  await browser.elements['#saved-list'].children[0].children[1].handlers.click();
  assert.equal(browser.elements['#saved-list'].children.length, 1);
  await browser.elements['#saved-list'].children[0].children[1].handlers.click();
  assert.equal(browser.elements['#saved-list'].children.length, 0);
  assert.equal(browser.calls[0].url, browser.calls[1].url);
});

test('right swipe deletes and left swipe edits; synthetic click never sends', async () => {
  for (const direction of [1, -1]) {
    const browser = await page(async (url, options) => response(options.method === 'DELETE'
      ? { deleted: 'e'.repeat(32) } : { status: 'sent', receivers: 1 }), false,
    { authenticated: true, messages: [], saved: [{ id: 'e'.repeat(32), content: 'swipe me' }] });
    const item = browser.elements['#saved-list'].children[0].children[0];
    const touch = { pointerType: 'pen', pointerId: 1, isPrimary: true, clientX: 100, clientY: 100, preventDefault() {} };
    item.handlers.pointerdown(touch);
    item.handlers.pointermove({ ...touch, clientX: 100 + direction * 80 });
    assert.equal(item.dataset.swipe, direction > 0 ? 'delete' : 'edit');
    await item.handlers.pointerup({ ...touch, clientX: 100 + direction * 80 });
    await item.handlers.click({ detail: 1 });
    const mutations = browser.calls.filter((call) => call.options.method !== 'GET');
    assert.equal(mutations.length, direction > 0 ? 1 : 0);
    if (direction > 0) {
      assert.equal(mutations[0].options.method, 'DELETE');
    } else {
      assert.equal(browser.elements['#message'].value, 'swipe me');
      assert.equal(browser.elements['#saved-list'].children.length, 1);
    }
  }
});

test('left swipe appends to the current draft without sending or removing the saved message', async () => {
  const browser = await page(() => { throw new Error('Editing must not request'); }, false,
    { authenticated: true, messages: [], saved: [{ id: 'e'.repeat(32), content: 'saved text' }] });
  browser.elements['#message'].value = 'current draft';
  let focused = false;
  browser.elements['#message'].focus = () => { focused = true; };
  const item = browser.elements['#saved-list'].children[0].children[0];
  const touch = { pointerType: 'pen', pointerId: 1, clientX: 100, clientY: 100, preventDefault() {} };
  item.handlers.pointerdown(touch);
  item.handlers.pointerup({ ...touch, clientX: 20 });
  item.handlers.click({ detail: 1 });
  assert.equal(browser.elements['#message'].value, 'current draft\nsaved text');
  assert.equal(focused, true);
  assert.equal(browser.calls.length, 0);
  assert.equal(browser.elements['#saved-list'].children.length, 1);
});

test('vertical scrolling and cancelled gestures never send or delete', async () => {
  const browser = await page(() => { throw new Error('Scroll must not request'); }, false,
    { authenticated: true, messages: [], saved: [{ id: 'e'.repeat(32), content: 'keep me' }] });
  const item = browser.elements['#saved-list'].children[0].children[0];
  const touch = { pointerType: 'pen', pointerId: 1, clientX: 100, clientY: 100, preventDefault() {} };
  item.handlers.pointerdown(touch);
  item.handlers.pointermove({ ...touch, clientX: 105, clientY: 200 });
  item.handlers.pointerup({ ...touch, clientX: 105, clientY: 200 });
  item.handlers.click({ detail: 1 });
  item.handlers.pointerdown(touch);
  item.handlers.pointermove({ ...touch, clientX: 180 });
  item.handlers.pointercancel({ pointerType: 'pen' });
  item.handlers.pointerup({ ...touch, clientX: 180 });
  item.handlers.click({ detail: 1 });
  assert.equal(browser.calls.length, 0);
  assert.equal(browser.elements['#saved-list'].children.length, 1);
});


test('resending moves the message to the front immediately while history refresh hangs', async () => {
  const browser = await page(async () => response({ status: 'sent', receivers: 1, message_id: 4 }), true, {
    authenticated: true, saved: [], messages: [
      { id: 3, received_at: '2026-10-18T03:00:00Z', content: 'newer' },
      { id: 2, received_at: '2026-10-18T02:00:00Z', content: 'resend me' },
      { id: 1, received_at: '2026-10-18T01:00:00Z', content: 'oldest' },
    ],
  });
  const list = browser.elements['#history-list'];
  browser.elements['#message'].value = 'keep draft';
  list.scrollTop = 200;
  await list.children[1].handlers.click();
  assert.deepEqual(list.children.map((item) => item.children[1].textContent), ['resend me', 'newer', 'oldest']);
  assert.equal(list.scrollTop, 0);
  assert.equal(browser.elements['#message'].value, 'keep draft');
  assert.equal(JSON.parse(browser.calls[0].options.body).message, 'resend me');
});

test('reloaded history keeps only the most recent occurrence of repeated content', async () => {
  const browser = await page(() => { throw new Error('Bootstrap must not fetch'); }, false, {
    authenticated: true, saved: [], messages: [
      { id: 3, received_at: '2026-10-18T03:00:00Z', content: 'repeated' },
      { id: 2, received_at: '2026-10-18T02:00:00Z', content: 'other' },
      { id: 1, received_at: '2026-10-18T01:00:00Z', content: 'repeated' },
    ],
  });
  const items = browser.elements['#history-list'].children;
  assert.deepEqual(items.map((item) => item.children[1].textContent), ['repeated', 'other']);
  assert.equal(items[0].children[0].dateTime, '2026-10-18T03:00:00Z');
});


test('history left swipe restores the draft and right swipe favorites without sending', async () => {
  for (const direction of [-1, 1]) {
    const browser = await page(async (url, options) => {
      assert.equal(url, './api/favorites');
      assert.equal(JSON.parse(options.body).message, 'history text');
      return response({ id: 1, content: 'history text' });
    }, true, { authenticated: true, saved: [], messages: [
      { id: 3, received_at: '2026-10-18T03:00:00Z', content: 'history text' },
    ] });
    browser.elements['#message'].value = 'current draft';
    const item = browser.elements['#history-list'].children[0];
    const touch = { pointerType: 'pen', pointerId: 1, clientX: 100, clientY: 100, preventDefault() {} };
    item.handlers.pointerdown(touch);
    item.handlers.pointermove({ ...touch, clientX: 100 + direction * 80 });
    assert.equal(item.dataset.swipe, direction > 0 ? 'favorite' : 'edit');
    await item.handlers.pointerup({ ...touch, clientX: 100 + direction * 80 });
    await item.handlers.click({ detail: 1 });
    if (direction < 0) {
      assert.equal(browser.elements['#message'].value, 'current draft\nhistory text');
      assert.equal(browser.calls.length, 0);
    } else {
      assert.equal(browser.elements['#message'].value, 'current draft');
      assert.equal(browser.calls.length, 1);
      assert.equal(favoriteRows(browser)[0].children[0].children[1].textContent, 'history text');
    }
  }
});

test('favorite can be sent repeatedly with fresh ids and removed independently', async () => {
  const ids = [];
  const browser = await page(async (url, options) => {
    if (options.method === 'DELETE') {
      assert.equal(url, './api/favorites/7');
      return response({ deleted: 7 });
    }
    assert.equal(url, './api/messages');
    const payload = JSON.parse(options.body);
    ids.push(payload.request_id);
    assert.equal(payload.message, 'favorite text');
    return response({ status: 'sent', receivers: 1, message_id: ids.length });
  }, true, { authenticated: true, messages: [], saved: [], favorites: [{ id: 7, content: 'favorite text' }] });
  browser.elements['#message'].value = 'keep draft';
  const row = favoriteRows(browser)[0];
  await row.children[0].handlers.click();
  await row.children[0].handlers.click();
  assert.equal(ids.length, 2);
  assert.notEqual(ids[0], ids[1]);
  assert.equal(favoriteRows(browser).length, 1);
  assert.equal(row.children.length, 1);
  row.children[0].handlers.touchstart(touchEvent([finger(100, 100)]));
  await row.children[0].handlers.touchend(touchEvent([], [finger(150, 100)]));
  assert.equal(favoriteRows(browser).length, 0);
  assert.equal(browser.elements['#message'].value, 'keep draft');
});

test('failed favorite leaves history intact and never sends', async () => {
  const browser = await page(async () => response('favorite failed', 500), true, {
    authenticated: true, saved: [], messages: [{ id: 3, received_at: '2026-10-18T03:00:00Z', content: 'keep' }],
  });
  const item = browser.elements['#history-list'].children[0];
  const touch = { pointerType: 'pen', pointerId: 1, clientX: 100, clientY: 100, preventDefault() {} };
  item.handlers.pointerdown(touch);
  await item.handlers.pointerup({ ...touch, clientX: 180 });
  await item.handlers.click({ detail: 1 });
  assert.equal(browser.calls.length, 1);
  assert.equal(browser.elements['#history-list'].children.length, 1);
  assert.equal(favoriteRows(browser).length, 0);
  assert.match(browser.elements['#status'].textContent, /favorite failed/);
});


function finger(x, y, id = 1) { return { identifier: id, clientX: x, clientY: y }; }
function touchEvent(touches, changedTouches = touches) {
  return { touches, changedTouches, cancelable: true, prevented: false,
    preventDefault() { this.prevented = true; } };
}
async function historyPage(exchange = () => { throw new Error('Editing must not send'); }) {
  return page(exchange, true, { authenticated: true, saved: [], messages: [
    { id: 3, received_at: '2026-10-18T03:00:00Z', content: 'thumb text' },
  ] });
}

test('single thumb diagonal swipe claims horizontal motion early and edits once', async () => {
  const browser = await historyPage();
  const item = browser.elements['#history-list'].children[0];
  assert.equal(item.listenerOptions.touchmove.passive, false);
  item.handlers.touchstart(touchEvent([finger(100, 100)]));
  // The browser may cancel the pointer stream while Touch Events remain active.
  item.handlers.pointercancel({ pointerType: 'touch' });
  const early = touchEvent([finger(92, 106)]);
  item.handlers.touchmove(early);
  assert.equal(early.prevented, true);
  const moved = touchEvent([finger(60, 132)]);
  item.handlers.touchmove(moved);
  assert.equal(item.dataset.swipe, 'edit');
  const end = touchEvent([], [finger(60, 132)]);
  await item.handlers.touchend(end);
  await item.handlers.click({ detail: 1 });
  assert.equal(end.prevented, true);
  assert.equal(browser.elements['#message'].value, 'thumb text');
  assert.equal(browser.calls.length, 0);
});

test('single thumb right swipe favorites once despite duplicate pointer events', async () => {
  const browser = await historyPage(async () => response({ id: 1, content: 'thumb text' }));
  const item = browser.elements['#history-list'].children[0];
  item.handlers.pointerdown({ pointerType: 'touch', pointerId: 1, clientX: 100, clientY: 100 });
  item.handlers.touchstart(touchEvent([finger(100, 100)]));
  item.handlers.touchmove(touchEvent([finger(109, 106)]));
  item.handlers.touchmove(touchEvent([finger(140, 130)]));
  await item.handlers.touchend(touchEvent([], [finger(140, 130)]));
  await item.handlers.pointerup({ pointerType: 'touch', pointerId: 1, clientX: 140, clientY: 130 });
  await item.handlers.click({ detail: 1 });
  assert.equal(browser.calls.length, 1);
  assert.equal(browser.calls[0].url, './api/favorites');
});

test('vertical thumb scrolling stays native and cannot turn into a swipe action', async () => {
  const browser = await historyPage();
  const item = browser.elements['#history-list'].children[0];
  item.handlers.touchstart(touchEvent([finger(100, 100)]));
  const moved = touchEvent([finger(104, 112)]);
  item.handlers.touchmove(moved);
  assert.equal(moved.prevented, false);
  item.handlers.touchmove(touchEvent([finger(150, 135)]));
  await item.handlers.touchend(touchEvent([], [finger(150, 135)]));
  await item.handlers.click({ detail: 1 });
  assert.equal(browser.elements['#message'].value, '');
  assert.equal(browser.calls.length, 0);
});

test('multi touch and touchcancel abort the gesture without sending', async () => {
  for (const cancelling of ['second-finger', 'touchcancel']) {
    const browser = await historyPage();
    const item = browser.elements['#history-list'].children[0];
    item.handlers.touchstart(touchEvent([finger(100, 100)]));
    item.handlers.touchmove(touchEvent([finger(60, 100)]));
    if (cancelling === 'second-finger') {
      item.handlers.touchstart(touchEvent([finger(60, 100), finger(90, 120, 2)]));
    } else {
      item.handlers.touchcancel();
    }
    await item.handlers.touchend(touchEvent([], [finger(60, 100)]));
    await item.handlers.click({ detail: 1 });
    assert.equal(browser.elements['#message'].value, '');
    assert.equal(browser.calls.length, 0);
  }
});

test('a short single finger tap still sends normally', async () => {
  const browser = await historyPage(async () => response({ status: 'sent', receivers: 1, message_id: 4 }));
  const item = browser.elements['#history-list'].children[0];
  item.handlers.touchstart(touchEvent([finger(100, 100)]));
  await item.handlers.touchend(touchEvent([], [finger(102, 102)]));
  await item.handlers.click({ detail: 1 });
  assert.equal(browser.calls.length, 2); // One send and one independent history refresh.
  assert.equal(browser.calls[0].url, './api/messages');
});


test('favorite single thumb left swipe edits without sending or removing the favorite', async () => {
  for (const draft of ['', 'current draft']) {
    const browser = await page(() => { throw new Error('Editing must not request'); }, true, {
      authenticated: true, messages: [], saved: [], favorites: [{ id: 7, content: 'favorite text' }],
    });
    browser.elements['#message'].value = draft;
    let focused = false;
    browser.elements['#message'].focus = () => { focused = true; };
    const item = favoriteRows(browser)[0].children[0];
    item.handlers.touchstart(touchEvent([finger(100, 100)]));
    const early = touchEvent([finger(92, 106)]);
    item.handlers.touchmove(early);
    assert.equal(early.prevented, true);
    item.handlers.touchmove(touchEvent([finger(60, 130)]));
    assert.equal(item.dataset.swipe, 'edit');
    await item.handlers.touchend(touchEvent([], [finger(60, 130)]));
    await item.handlers.click({ detail: 1 });
    assert.equal(browser.elements['#message'].value, draft ? 'current draft\nfavorite text' : 'favorite text');
    assert.equal(focused, true);
    assert.equal(favoriteRows(browser).length, 1);
    assert.equal(browser.calls.length, 0);
  }
});

test('favorite vertical scrolling never sends or removes', async () => {
  for (const [x, y] of [[104, 160]]) {
    const browser = await page(() => { throw new Error('Gesture must not request'); }, true, {
      authenticated: true, messages: [], saved: [], favorites: [{ id: 7, content: 'favorite text' }],
    });
    const item = favoriteRows(browser)[0].children[0];
    item.handlers.touchstart(touchEvent([finger(100, 100)]));
    item.handlers.touchmove(touchEvent([finger(x, y)]));
    assert.equal(item.dataset.swipe, undefined);
    await item.handlers.touchend(touchEvent([], [finger(x, y)]));
    await item.handlers.click({ detail: 1 });
    assert.equal(browser.elements['#message'].value, '');
    assert.equal(favoriteRows(browser).length, 1);
    assert.equal(browser.calls.length, 0);
  }
});


async function sortableFavorites(exchange) {
  const favorites = [1, 2, 3].map((id) => ({ id, content: `favorite ${id}` }));
  const browser = await page(exchange, true, { authenticated: true, messages: [], saved: [], favorites });
  const list = favoriteContainer(browser);
  for (const row of list.children) row.getBoundingClientRect = () => ({ top: list.children.indexOf(row) * 60, height: 60 });
  return browser;
}

test('long press drags favorites up and down and persists the resulting order without sending', async () => {
  for (const [index, y, expected] of [[0, 210, [2, 3, 1]], [2, 5, [3, 1, 2]]]) {
    const browser = await sortableFavorites(async (url, options) => {
      assert.equal(url, './api/favorites/order');
      assert.deepEqual(JSON.parse(options.body).ids, expected);
      return response({ favorites: expected.map((id) => ({ id, content: `favorite ${id}` })) });
    });
    browser.elements['#message'].value = 'keep draft';
    const list = favoriteContainer(browser);
    const item = list.children[index].children[0];
    const startY = index * 60 + 30;
    item.handlers.touchstart(touchEvent([finger(100, startY)]));
    browser.hold();
    assert.equal(item.dataset.dragging, 'true');
    const move = touchEvent([finger(100, y)]);
    item.handlers.touchmove(move);
    assert.equal(move.prevented, true);
    await item.handlers.touchend(touchEvent([], [finger(100, y)]));
    await item.handlers.click({ detail: 1 });
    assert.deepEqual(favoriteContainer(browser).children.map((row) => Number(row.dataset.favoriteId)), expected);
    assert.equal(browser.calls.length, 1);
    assert.equal(browser.elements['#message'].value, 'keep draft');
    assert.equal(browser.elements['#send-submit'].disabled, false);
  }
});

test('cancelled or unchanged long press never saves or sends', async () => {
  for (const cancel of [true, false]) {
    const browser = await sortableFavorites(() => { throw new Error('Must not request'); });
    const list = favoriteContainer(browser);
    const item = list.children[0].children[0];
    item.handlers.touchstart(touchEvent([finger(100, 30)]));
    browser.hold();
    if (cancel) {
      item.handlers.touchmove(touchEvent([finger(100, 210)]));
      item.handlers.touchcancel();
    } else {
      await item.handlers.touchend(touchEvent([], [finger(100, 30)]));
    }
    await item.handlers.click({ detail: 1 });
    assert.deepEqual(favoriteContainer(browser).children.map((row) => Number(row.dataset.favoriteId)), [1, 2, 3]);
    assert.equal(browser.calls.length, 0);
    assert.equal(browser.elements['#send-submit'].disabled, false);
  }
});

test('failed order save reports the error and restores the displayed order', async () => {
  const browser = await sortableFavorites(async () => response('收藏列表已改变，请刷新后重新排序', 409));
  const list = favoriteContainer(browser);
  const item = list.children[0].children[0];
  item.handlers.touchstart(touchEvent([finger(100, 30)]));
  browser.hold();
  item.handlers.touchmove(touchEvent([finger(100, 210)]));
  await item.handlers.touchend(touchEvent([], [finger(100, 210)]));
  assert.deepEqual(favoriteContainer(browser).children.map((row) => Number(row.dataset.favoriteId)), [1, 2, 3]);
  assert.match(browser.elements['#status'].textContent, /刷新/);
  assert.equal(browser.elements['#status'].dataset.error, 'true');
});

test('moving before the hold threshold remains a scroll instead of a reorder', async () => {
  const browser = await sortableFavorites(() => { throw new Error('Must not request'); });
  const item = favoriteRows(browser)[0].children[0];
  item.handlers.touchstart(touchEvent([finger(100, 30)]));
  const move = touchEvent([finger(100, 50)]);
  item.handlers.touchmove(move);
  browser.hold();
  assert.equal(move.prevented, false);
  assert.equal(item.dataset.dragging, undefined);
  await item.handlers.touchend(touchEvent([], [finger(100, 210)]));
  await item.handlers.click({ detail: 1 });
  assert.equal(browser.calls.length, 0);
});


const grouped = {
  authenticated: true, messages: [], saved: [], favorite_groups: [{ id: 5, name: 'Work' }], favorites: [
    { id: 1, content: 'ungrouped', group_id: 0, group_position: null },
    { id: 2, content: 'work A', group_id: 5, group_position: 1 },
    { id: 3, content: 'work B', group_id: 5, group_position: 0 },
  ],
};

function swipeGroup(browser, id) {
  const heading = favoriteBox(browser, id).children[0];
  heading.handlers.touchstart(touchEvent([finger(120, 20)]));
  heading.handlers.touchmove(touchEvent([finger(40, 20)]));
  heading.handlers.touchend(touchEvent([], [finger(40, 20)]));
}

test('group boxes show counts and compact cards without the legacy management bar', async () => {
  const browser = await page(() => { throw new Error('Rendering must not request'); }, true, grouped);
  assert.equal(favoriteBox(browser, 0).children[0].children[0].textContent, '未分组 · 1');
  assert.equal(favoriteBox(browser, 5).children[0].children[0].textContent, 'Work · 2');
  assert.deepEqual(favoriteContainer(browser, 5).children.map((row) => Number(row.dataset.favoriteId)), [3, 2]);
  assert.equal(favoriteRows(browser)[0].children[0].children[0].textContent, '');
  assert.equal(browser.calls.length, 0);
});

test('swiping a group title opens rename without sending or changing the draft', async () => {
  const browser = await page(async (url, options) => {
    assert.equal(url, './api/favorite-groups/5');
    assert.equal(options.method, 'PATCH');
    assert.deepEqual(JSON.parse(options.body), { name: 'Research' });
    return response({ favorites: grouped.favorites, favorite_groups: [{ id: 5, name: 'Research' }] });
  }, true, grouped);
  browser.elements['#message'].value = 'keep draft';
  let editor = favoriteBox(browser, 5).querySelector('.group-rename-editor');
  assert.equal(editor.hidden, true);
  swipeGroup(browser, 5);
  assert.equal(editor.hidden, false);
  assert.equal(editor.children[0].value, 'Work');
  assert.equal(browser.calls.length, 0);
  editor.children[0].value = 'Research';
  await editor.children[1].handlers.click();
  assert.equal(favoriteBox(browser, 5).children[0].children[0].textContent, 'Research · 2');
  assert.equal(favoriteBox(browser, 5).querySelector('.group-rename-editor').hidden, true);
  assert.equal(browser.elements['#message'].value, 'keep draft');
});

test('reserved group cannot be renamed and cancelling rename makes no request', async () => {
  const browser = await page(() => { throw new Error('Cancel must not request'); }, true, grouped);
  swipeGroup(browser, 0);
  assert.equal(favoriteBox(browser, 0).children.length, 2);
  swipeGroup(browser, 5);
  const editor = favoriteBox(browser, 5).querySelector('.group-rename-editor');
  editor.children[0].value = 'unsaved';
  editor.children[2].handlers.click();
  assert.equal(editor.hidden, true);
  swipeGroup(browser, 5);
  assert.equal(editor.children[0].value, 'Work');
  assert.equal(browser.calls.length, 0);
});

test('group reorder submits only visible ids and preserves the other groups', async () => {
  const browser = await page(async (url, options) => {
    assert.equal(url, './api/favorites/order');
    assert.deepEqual(JSON.parse(options.body), { ids: [2, 3], group_id: 5 });
    return response({ favorites: grouped.favorites.map((entry) => ({ ...entry,
      group_position: entry.id === 2 ? 0 : entry.id === 3 ? 1 : null })) });
  }, true, grouped);
  favoriteBox(browser, 0).getBoundingClientRect = () => ({ top: -500, bottom: -100, left: 0, right: 400, height: 400 });
  const list = favoriteContainer(browser, 5);
  for (const row of list.children) row.getBoundingClientRect = () => ({ top: list.children.indexOf(row) * 60, height: 60 });
  const item = list.children[0].children[0];
  item.handlers.touchstart(touchEvent([finger(100, 30)]));
  browser.hold();
  item.handlers.touchmove(touchEvent([finger(100, 180)]));
  await item.handlers.touchend(touchEvent([], [finger(100, 180)]));
  assert.deepEqual(favoriteContainer(browser, 5).children.map((row) => Number(row.dataset.favoriteId)), [2, 3]);
  assert.deepEqual(favoriteRows(browser).map((row) => Number(row.dataset.favoriteId)), [1, 2, 3]);
});

test('failed rename keeps the entered name editable and Enter retries', async () => {
  const browser = await page(async () => response('分组名称已存在', 409), true, grouped);
  swipeGroup(browser, 5);
  const editor = favoriteBox(browser, 5).querySelector('.group-rename-editor');
  const input = editor.children[0];
  input.value = 'duplicate';
  await editor.children[1].handlers.click();
  assert.equal(editor.hidden, false);
  assert.equal(input.value, 'duplicate');
  assert.equal(input.disabled, false);
  assert.match(browser.elements['#status'].textContent, /已存在/);
  await input.handlers.keydown({ key: 'Enter', preventDefault() {} });
  assert.equal(browser.calls.length, 2);
  input.handlers.keydown({ key: 'Escape', preventDefault() {} });
  assert.equal(editor.hidden, true);
});

function layoutGroupBoxes(browser) {
  for (const [index, box] of browser.elements['#favorite-list'].children.entries()) {
    box.getBoundingClientRect = () => ({ top: index * 200, bottom: index * 200 + 180, height: 180, left: 0, right: 400 });
    for (const [rowIndex, row] of box.querySelector('.favorite-group-items').children.entries()) row.getBoundingClientRect = () => ({ top: index * 200 + 20 + rowIndex * 60, height: 40 });
  }
  browser.elements['#favorite-new-group'].getBoundingClientRect = () => ({ top: 500, bottom: 600, height: 100, left: 0, right: 400 });
}

test('dragging a message into another box saves membership and insertion order in one request', async () => {
  const browser = await page(async (url, options) => {
    assert.equal(url, './api/favorites/move');
    assert.deepEqual(JSON.parse(options.body), { ids: [1], group_id: 5, order: [1, 3, 2] });
    return response({ favorite_groups: grouped.favorite_groups, favorites: grouped.favorites.map((entry) => ({ ...entry, group_id: 5, group_position: entry.id === 1 ? 0 : entry.id === 3 ? 1 : 2 })) });
  }, true, grouped);
  layoutGroupBoxes(browser);
  browser.elements['#message'].value = 'keep draft';
  const item = favoriteContainer(browser, 0).children[0].children[0];
  item.handlers.touchstart(touchEvent([finger(100, 30)]));
  browser.hold();
  item.handlers.touchmove(touchEvent([finger(100, 210)]));
  assert.equal(favoriteBox(browser, 5).dataset.drop, 'true');
  await item.handlers.touchend(touchEvent([], [finger(100, 210)]));
  await item.handlers.click({ detail: 1 });
  assert.equal(favoriteContainer(browser, 0).children.length, 0);
  assert.deepEqual(favoriteContainer(browser, 5).children.map((row) => Number(row.dataset.favoriteId)), [1, 3, 2]);
  assert.equal(browser.calls.length, 1);
  assert.equal(browser.elements['#message'].value, 'keep draft');
});

test('dropping on new group waits for a name before atomically creating and moving', async () => {
  const browser = await page(async (url, options) => {
    assert.equal(url, './api/favorite-groups');
    assert.deepEqual(JSON.parse(options.body), { name: 'New', ids: [1] });
    return response({ favorite_groups: [...grouped.favorite_groups, { id: 9, name: 'New' }], favorites: grouped.favorites.map((entry) => ({ ...entry, group_id: entry.id === 1 ? 9 : entry.group_id })) });
  }, true, grouped);
  layoutGroupBoxes(browser);
  const item = favoriteContainer(browser, 0).children[0].children[0];
  item.handlers.touchstart(touchEvent([finger(100, 30)]));
  browser.hold();
  item.handlers.touchmove(touchEvent([finger(100, 550)]));
  await item.handlers.touchend(touchEvent([], [finger(100, 550)]));
  assert.equal(browser.calls.length, 0);
  assert.equal(browser.elements['#favorite-new-editor'].hidden, false);
  assert.equal(favoriteContainer(browser, 0).children.length, 1);
  browser.elements['#favorite-new-name'].value = 'New';
  await browser.elements['#favorite-new-save'].handlers.click();
  assert.equal(favoriteContainer(browser, 9).children.length, 1);
  assert.equal(browser.elements['#favorite-new-editor'].hidden, true);
});

test('group title long press reorders entire boxes, including ungrouped', async () => {
  const browser = await page(async (url, options) => {
    assert.equal(url, './api/favorite-groups/order');
    assert.deepEqual(JSON.parse(options.body), { ids: [5, 0] });
    return response({ favorites: grouped.favorites, favorite_groups: grouped.favorite_groups, favorite_group_order: [5, 0] });
  }, true, grouped);
  layoutGroupBoxes(browser);
  const handle = favoriteBox(browser, 0).children[0];
  handle.handlers.touchstart(touchEvent([finger(100, 10)]));
  browser.hold();
  handle.handlers.touchmove(touchEvent([finger(100, 400)]));
  await handle.handlers.touchend(touchEvent([], [finger(100, 400)]));
  await handle.handlers.click({ detail: 1 });
  assert.deepEqual(browser.elements['#favorite-list'].children.map((box) => Number(box.dataset.groupId)), [5, 0]);
  assert.equal(favoriteRows(browser).length, 3);
  assert.equal(browser.calls.length, 1);
});

test('cancelling a group drag or a new-group drop preserves every message', async () => {
  const browser = await page(() => { throw new Error('Cancellation must not request'); }, true, grouped);
  layoutGroupBoxes(browser);
  const handle = favoriteBox(browser, 0).children[0];
  handle.handlers.touchstart(touchEvent([finger(100, 10)]));
  browser.hold();
  handle.handlers.touchmove(touchEvent([finger(100, 400)]));
  handle.handlers.touchcancel();
  assert.deepEqual(browser.elements['#favorite-list'].children.map((box) => Number(box.dataset.groupId)), [0, 5]);
  layoutGroupBoxes(browser);
  const item = favoriteContainer(browser, 0).children[0].children[0];
  item.handlers.touchstart(touchEvent([finger(100, 30)]));
  browser.hold();
  item.handlers.touchmove(touchEvent([finger(100, 550)]));
  await item.handlers.touchend(touchEvent([], [finger(100, 550)]));
  browser.elements['#favorite-new-cancel'].handlers.click();
  assert.equal(browser.elements['#favorite-new-editor'].hidden, true);
  assert.equal(favoriteContainer(browser, 0).children.length, 1);
  assert.equal(browser.calls.length, 0);
});
