// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Cognitio S.r.l.

// The chat page. It sends each message to this server, which forwards it to
// the agent; the agent keeps the conversation. The browser keeps only the
// conversation's name, so a reload continues the same conversation.

const THREAD_KEY = 'quickstart-chat-thread';

// The thread names the server accepts, as the server writes them into the page.
// With no pattern on the page, no stored name is trusted.
const THREAD_NAME = new RegExp(document.body.dataset.threadPattern || '^$');

const list = document.getElementById('messages');
const empty = document.getElementById('empty');
const form = document.getElementById('ask');
const input = document.getElementById('message');
const send = document.getElementById('send');
const threadLabel = document.getElementById('thread');

// A new conversation's name: "chat-" and twelve random hexadecimal digits.
function newThread() {
  const bytes = new Uint8Array(6);
  crypto.getRandomValues(bytes);
  return 'chat-' + Array.from(bytes, (b) => b.toString(16).padStart(2, '0')).join('');
}

function currentThread() {
  let thread = localStorage.getItem(THREAD_KEY);
  // The stored name is checked against the server's pattern before it is used,
  // so a value the browser holds from elsewhere starts a new conversation
  // instead of a refused request.
  if (!thread || !THREAD_NAME.test(thread)) {
    thread = newThread();
    localStorage.setItem(THREAD_KEY, thread);
  }
  return thread;
}

let thread = currentThread();

// Adds one message to the list. Text is set as text, never as markup.
function show(role, text, note) {
  empty.hidden = true;
  const item = document.createElement('li');
  item.className = role;
  const body = document.createElement('p');
  body.textContent = text;
  item.append(body);
  if (note) {
    const small = document.createElement('small');
    small.textContent = note;
    item.append(small);
  }
  list.append(item);
  item.scrollIntoView({ block: 'end' });
  return item;
}

async function call(method, path, body) {
  const response = await fetch(path, {
    method,
    headers: body ? { 'Content-Type': 'application/json' } : {},
    body: body ? JSON.stringify(body) : undefined,
  });
  let data = {};
  try {
    data = await response.json();
  } catch {
    // An answer that is not JSON is reported by its status below.
  }
  if (!response.ok) {
    throw new Error(data.error || `the server answered HTTP ${response.status}`);
  }
  return data;
}

async function load() {
  list.replaceChildren();
  empty.hidden = false;
  threadLabel.textContent = thread;
  try {
    const conversation = await call('GET', `/threads/${thread}`);
    for (const message of conversation.messages || []) {
      if (message.role === 'user' || message.role === 'assistant') {
        show(message.role, message.content);
      }
    }
  } catch (error) {
    show('error', `The conversation could not be read: ${error.message}`);
  }
}

form.addEventListener('submit', async (event) => {
  event.preventDefault();
  const message = input.value.trim();
  if (!message) return;
  input.value = '';
  send.disabled = true;
  show('user', message);
  const waiting = show('assistant pending', 'Thinking…');
  try {
    const reply = await call('POST', `/threads/${thread}/turns`, { message });
    waiting.remove();
    show('assistant', reply.answer, reply.model ? `answered by ${reply.model}` : '');
  } catch (error) {
    waiting.remove();
    show('error', error.message);
    // A refused message goes back into the box, so it can be shortened and sent again.
    if (!input.value) input.value = message;
  } finally {
    send.disabled = false;
    input.focus();
  }
});

// Enter sends; Shift+Enter starts a new line.
input.addEventListener('keydown', (event) => {
  if (event.key === 'Enter' && !event.shiftKey && !event.isComposing) {
    event.preventDefault();
    form.requestSubmit();
  }
});

document.getElementById('new').addEventListener('click', () => {
  thread = newThread();
  localStorage.setItem(THREAD_KEY, thread);
  load();
  input.focus();
});

load();
