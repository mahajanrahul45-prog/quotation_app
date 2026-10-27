const assert = require('node:assert/strict');
const {readFileSync} = require('node:fs');
const {test} = require('node:test');
const vm = require('node:vm');
const {join} = require('node:path');

test('Firebase SDK is cached online and reusable without network', async () => {
  const entries = new Map();
  let listener, online = true, requests = 0, imported;
  const response = {ok: true, type: 'cors', clone() {return this;}};
  vm.runInNewContext(readFileSync(join(__dirname, '../web/offline_service_worker.js'), 'utf8'), {
    URL,
    importScripts(url) {imported = url;},
    self: {addEventListener(name, callback) {listener = callback;}},
    caches: {async open() {return {
      async match(request) {return entries.get(request.url);},
      async put(request, value) {entries.set(request.url, value);},
    };}},
    async fetch() {requests++; if (!online) throw Error('offline'); return response;},
  });
  assert.equal(imported, 'flutter_service_worker.js');
  let result;
  const request = {method: 'GET', url: 'https://www.gstatic.com/firebasejs/12.0.0/firebase-auth.js'};
  listener({request, respondWith(value) {result = value;}});
  assert.equal(await result, response);
  online = false;
  listener({request, respondWith(value) {result = value;}});
  assert.equal(await result, response);
  assert.equal(requests, 1);
  listener({request: {method: 'GET', url: 'https://firestore.googleapis.com/private-data'},
    respondWith() {assert.fail('Business requests must not use the SDK cache');}});
});
