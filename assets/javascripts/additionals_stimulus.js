/* exported AdditionalsHelpers */
// Foundation for Stimulus controllers — provides shared helpers (CSRF, fetch)

window.AdditionalsHelpers = {
  csrfToken() {
    const meta = document.querySelector('meta[name="csrf-token"]');
    return meta && meta.content;
  },

  async fetchJSON(url, options = {}) {
    const { headers, ...rest } = options;
    const merged = {
      'X-CSRF-Token': this.csrfToken(),
      'Accept': 'application/json',
      ...headers
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
  }
};
