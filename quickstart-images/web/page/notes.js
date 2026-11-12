// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Cognitio S.r.l.

// The notes page. It sends the same requests a reader can send with curl: it
// asks / for what the app is connected to, lists the notes with GET /notes,
// stores one with POST /notes and reads one with GET /notes/{id}. Each read is
// shown with where the app says it came from, its "source" field.

// What the page says about where a read came from, by the app's "source" value.
const SOURCE_WORDS = {
  postgresql: 'from PostgreSQL',
  cache: 'from the cache',
};

// The "cache" value / answers with when no cache is wired to the app.
const NO_CACHE = 'not wired';

const form = document.getElementById('add');
const input = document.getElementById('text');
const save = document.getElementById('save');
const status = document.getElementById('status');
const list = document.getElementById('notes');
const empty = document.getElementById('empty');

// Every read of a note made from this page, by note id, oldest first.
const reads = new Map();

// call sends one request to the app and returns its JSON answer. It is this
// page's own: each quickstart image builds from its own directory, so the chat
// page's function of the same name cannot be shared.
async function call(method, path, body) {
  const response = await fetch(path, {
    method,
    headers: { Accept: 'application/json' },
    body,
  });
  let data = {};
  try {
    data = await response.json();
  } catch {
    // An answer that is not JSON is reported by its status below.
  }
  if (!response.ok) {
    throw new Error(data.error || `the app answered HTTP ${response.status}`);
  }
  return data;
}

function sourceWords(source) {
  return SOURCE_WORDS[source] || `from ${source}`;
}

async function connection() {
  const database = document.getElementById('database');
  const cache = document.getElementById('cache');
  const note = document.getElementById('cache-note');
  try {
    const info = await call('GET', '/');
    database.textContent = info.database;
    if (info.cache === NO_CACHE) {
      cache.textContent = 'none';
      note.textContent = 'No cache is wired to the app, so every read comes from PostgreSQL.';
    } else {
      cache.textContent = info.cache;
      note.textContent =
        'A cache is wired to the app: the first read of a note comes from PostgreSQL, and the next reads come from ' +
        'the cache while it keeps the note.';
    }
  } catch (error) {
    database.textContent = 'unknown';
    cache.textContent = 'unknown';
    note.textContent = `The app could not say what it is connected to: ${error.message}`;
  }
}

// Writes the reads of one note into its list. Text is set as text, never as markup.
function showReads(id, into) {
  into.replaceChildren();
  (reads.get(id) || []).forEach((source, index) => {
    const item = document.createElement('li');
    item.className = source === 'cache' ? 'read cache' : 'read';
    item.textContent = `Read ${index + 1}: ${sourceWords(source)}`;
    into.append(item);
  });
}

async function readNote(id, button, into) {
  button.disabled = true;
  try {
    const answer = await call('GET', `/notes/${id}`);
    if (!reads.has(id)) reads.set(id, []);
    reads.get(id).push(answer.source);
    showReads(id, into);
  } catch (error) {
    status.textContent = `Note ${id} could not be read: ${error.message}`;
  } finally {
    button.disabled = false;
  }
}

function showNote(n) {
  const item = document.createElement('li');
  item.className = 'note';

  const head = document.createElement('div');
  head.className = 'note-head';
  const label = document.createElement('span');
  label.className = 'note-id';
  label.textContent = `Note ${n.id}`;
  const when = document.createElement('small');
  when.textContent = new Date(n.created_at).toLocaleString();
  const button = document.createElement('button');
  button.type = 'button';
  button.textContent = 'Read';
  head.append(label, when, button);

  const text = document.createElement('p');
  text.textContent = n.text;

  const readList = document.createElement('ul');
  readList.className = 'reads';
  readList.setAttribute('aria-live', 'polite');
  showReads(n.id, readList);
  button.addEventListener('click', () => readNote(n.id, button, readList));

  item.append(head, text, readList);
  list.append(item);
}

async function loadNotes() {
  try {
    const answer = await call('GET', '/notes');
    list.replaceChildren();
    const notes = answer.notes || [];
    notes.forEach(showNote);
    empty.hidden = notes.length > 0;
  } catch (error) {
    status.textContent = `The notes could not be listed: ${error.message}`;
  }
}

form.addEventListener('submit', async (event) => {
  event.preventDefault();
  const text = input.value;
  if (!text.trim()) return;
  save.disabled = true;
  try {
    const stored = await call('POST', '/notes', text);
    input.value = '';
    status.textContent = `Note ${stored.id} is stored in PostgreSQL.`;
    await loadNotes();
  } catch (error) {
    status.textContent = `The note could not be stored: ${error.message}`;
  } finally {
    save.disabled = false;
    input.focus();
  }
});

document.getElementById('refresh').addEventListener('click', () => {
  status.textContent = '';
  loadNotes();
});

connection();
loadNotes();
