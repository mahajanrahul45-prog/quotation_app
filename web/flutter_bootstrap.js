{{flutter_js}}
{{flutter_build_config}}

(() => {
  const status = document.getElementById('startup-status');
  const retry = document.getElementById('startup-retry');
  let started = false;
  const fail = () => {
    if (started) return;
    status.textContent = 'Could not open the app. Check your connection and try again.';
    retry.hidden = false;
  };
  retry.addEventListener('click', () => window.location.reload());
  const deadline = setTimeout(fail, 30000);
  window.addEventListener('error', fail);
  window.addEventListener('unhandledrejection', fail);

  const serviceWorkerVersion = {{flutter_service_worker_version}};
  _flutter.loader.load({
    serviceWorkerSettings: {
      serviceWorkerVersion,
      serviceWorkerUrl: new URL(`offline_service_worker.js?v=${serviceWorkerVersion}`, document.baseURI).href,
    },
    config: {
      // Flutter builds include these files; avoid a separate renderer CDN download.
      canvasKitBaseUrl: new URL('canvaskit/', document.baseURI).href,
    },
    onEntrypointLoaded: async (engineInitializer) => {
      try {
        const appRunner = await engineInitializer.initializeEngine();
        await appRunner.runApp();
        started = true;
        clearTimeout(deadline);
        window.removeEventListener('error', fail);
        window.removeEventListener('unhandledrejection', fail);
        document.getElementById('startup').remove();
      } catch (error) {
        console.error('Web startup failed', error);
        fail();
      }
    },
  }).catch(fail);
})();
