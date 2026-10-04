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
