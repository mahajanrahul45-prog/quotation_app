const assert = require('node:assert/strict');
const {readFileSync} = require('node:fs');
const {test} = require('node:test');
const vm = require('node:vm');
const {join} = require('node:path');

const source = readFileSync(join(__dirname, '../web/flutter_bootstrap.js'), 'utf8')
  .replace(/\{\{flutter_(?:js|build_config)\}\}/g, '')
  .replace('{{flutter_service_worker_version}}', '"test-version"');

function boot(load = () => Promise.resolve()) {
  const elements = {
    'startup-status': {textContent: 'Opening app...'},
    'startup-retry': {hidden: true, addEventListener(_, callback) {this.click = callback;}},
    startup: {remove() {this.removed = true;}},
  };
  const events = new Map();
  const result = {elements, events, reloaded: false, cleared: false};
  vm.runInNewContext(source, {
    URL,
    document: {baseURI: 'https://example.com/workspace/', getElementById: id => elements[id]},
    window: {
      location: {reload() {result.reloaded = true;}},
      addEventListener: (name, callback) => events.set(name, callback),
      removeEventListener: name => events.delete(name),
    },
    setTimeout(callback) {result.timeout = callback; return 1;},
    clearTimeout() {result.cleared = true;},
    console: {error() {}},
    _flutter: {loader: {load(options) {result.options = options; return load();}}},
  });
  return result;
}

test('renderer uses the app base path and successful startup removes the loader', async () => {
  const app = boot();
  assert.equal(app.options.config.canvasKitBaseUrl, 'https://example.com/workspace/canvaskit/');
  assert.equal(app.options.serviceWorkerSettings.serviceWorkerVersion, 'test-version');
  assert.equal(app.options.serviceWorkerSettings.serviceWorkerUrl, 'https://example.com/workspace/offline_service_worker.js?v=test-version');
  await app.options.onEntrypointLoaded({initializeEngine: async () => ({runApp: async () => {}})});
  assert.equal(app.elements.startup.removed, true);
  assert.equal(app.cleared, true);
  assert.equal(app.events.size, 0);
});

test('hung loading offers a reload and still accepts late successful startup', async () => {
  const app = boot();
  app.timeout();
  assert.equal(app.elements['startup-retry'].hidden, false);
  app.elements['startup-retry'].click();
  assert.equal(app.reloaded, true);
  await app.options.onEntrypointLoaded({initializeEngine: async () => ({runApp: async () => {}})});
  assert.equal(app.elements.startup.removed, true);
});

test('engine and entrypoint failures display a retry', async () => {
  const app = boot();
  await app.options.onEntrypointLoaded({initializeEngine: async () => {throw Error('blocked');}});
  assert.equal(app.elements['startup-retry'].hidden, false);
  const rejected = boot(() => Promise.reject(Error('missing entrypoint')));
  await Promise.resolve();
  assert.equal(rejected.elements['startup-retry'].hidden, false);
});
