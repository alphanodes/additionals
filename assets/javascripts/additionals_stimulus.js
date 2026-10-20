/* exported AdditionalsHelpers */
/* global setupHoverTooltips */
// Foundation for Stimulus controllers — provides shared helpers (CSRF, fetch),
// plus a global hook that re-initializes Redmine's jQuery UI tooltips after
// any DOM swap performed by our async controllers.

function reinitTooltipsAfterAsyncSwap() {
  if (typeof setupHoverTooltips === 'function') {
    setupHoverTooltips();
  }
}

document.addEventListener('remote-form:success', reinitTooltipsAfterAsyncSwap);
document.addEventListener('render-async:load', reinitTooltipsAfterAsyncSwap);

// Pending or finished loads of library assets, by URL
const additionalsAssetLoads = new Map();

// Loads one asset of a library unless the page has it already, e.g. from the
// libraries the server put into the head
function loadAdditionalsAsset({ type, url }) {
  const selector = type === 'css' ? `link[href="${url}"]` : `script[src="${url}"]`;
  if (document.querySelector(selector)) {
    return Promise.resolve();
  }
  if (!additionalsAssetLoads.has(url)) {
    additionalsAssetLoads.set(url, new Promise((resolve, reject) => {
      const element = document.createElement(type === 'css' ? 'link' : 'script');
      if (type === 'css') {
        element.rel = 'stylesheet';
        element.href = url;
      } else {
        element.src = url;
      }
      element.onload = resolve;
      element.onerror = () => {
        additionalsAssetLoads.delete(url);
        element.remove();
        reject(new Error(`Could not load ${url}`));
      };
      document.head.appendChild(element);
    }));
  }
  return additionalsAssetLoads.get(url);
}

window.AdditionalsHelpers = {
  csrfToken() {
    const meta = document.querySelector('meta[name="csrf-token"]');
    return meta && meta.content;
  },

  async fetchJSON(url, options = {}) {
    const { headers, ...rest } = options;
    const merged = {
      'X-CSRF-Token': this.csrfToken(),
      Accept: 'application/json',
      ...headers,
    };
    // Remove undefined values (e.g., Content-Type: undefined for FormData)
    Object.keys(merged).forEach((key) => {
      if (merged[key] === undefined) { delete merged[key]; }
    });
    const response = await fetch(url, { ...rest, headers: merged });

    if (!response.ok) {
      const err = await response.json().catch(() => ({ error: response.statusText }));
      throw new Error(err.error || response.statusText);
    }

    return response.json();
  },

  // Loads a library of Additionals::LibraryRegistry on demand, once per page,
  // e.g. for a block that needs it with certain settings only. The assets of
  // a library build on each other and load in order.
  loadLibrary(name) {
    const assets = (window.ADDITIONALS_LIBRARIES || {})[name];
    if (!assets) {
      return Promise.reject(new Error(`Unknown library: ${name}`));
    }
    return assets.reduce((loaded, asset) => loaded.then(() => loadAdditionalsAsset(asset)), Promise.resolve());
  },

  // Drops the unsaved flag of Redmine core's warnLeavingUnsaved after an async submit, which
  // the core submit listener does not see. Core keeps the flag in jQuery's internal data
  // store, so deleting a data-changed attribute (dataset) has no effect.
  // A focused textarea is blurred first: its pending change event, which core's leave check
  // triggers with blur() as well, would set the flag again. Focusing it again resets the
  // value the browser compares against.
  clearWarnLeavingUnsaved(textareas = 'textarea') {
    const $textareas = $(textareas);
    const focused = $textareas.toArray().includes(document.activeElement) ? document.activeElement : null;

    if (focused) { focused.blur(); }
    $textareas.removeData('changed');
    if (focused) { focused.focus(); }
  },
};
