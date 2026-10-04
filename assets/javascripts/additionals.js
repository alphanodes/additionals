/* exported openExternalUrlsInTab */
function openExternalUrlsInTab() {
  document.querySelectorAll('a.external').forEach(link => {
    link.setAttribute('target', '_blank');
    link.setAttribute('rel', 'noopener noreferrer');
  });
}

/* exported formatNameWithIcon */
function formatNameWithIcon(opt) {
  if (opt.loading) {
    return opt.name;
  }

  const span = document.createElement('span');
  if (opt.name_with_icon === undefined) {
    // text is a plain value (user, tag or contact name), parsing it as html
    // would run event handlers even on this detached span
    span.textContent = opt.text;
  } else {
    // name_with_icon is html built and escaped on the server side
    span.innerHTML = opt.name_with_icon;
  }
  return span;
}

/* Escape a value for html built in javascript. Quotes are escaped as well,
   because Redmine's sanitizeHTML leaves them as they are and a value inside
   an attribute could end it. */
/* exported escapeHtml */
function escapeHtml(value) {
  if (value === null || value === undefined) { return ''; }

  return String(value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

/* Tabler sprite helpers for javascript generated markup.

   The sprite paths carry an asset digest, so they cannot be built in
   javascript. ADDITIONALS_ICON_SPRITES is provided by the html head partial
   and maps a sprite key ('core', 'additionals', 'additionals_custom') to its
   asset path. */
/* global ADDITIONALS_ICON_SPRITES */
/* exported spriteIconPath */
function spriteIconPath(sprite) {
  if (typeof ADDITIONALS_ICON_SPRITES === 'undefined') { return ''; }

  return ADDITIONALS_ICON_SPRITES[sprite || 'core'] || '';
}

/* Build the markup of a sprite icon, as it is rendered by the sprite_icon
   helper on the server side. Redmine covers the plain cases itself:
   createSVGIcon builds an icon of the core sprite, updateSVGIcon swaps the icon
   of a rendered one. Use this where neither fits, so for an icon of another
   sprite or one that needs its own size, class or tooltip.

   options: sprite ('core' by default), size (18), cssClass, title (rendered as
   svg title element, which is what shows a tooltip on an svg) */
/* exported spriteIcon */
function spriteIcon(name, options) {
  const opts = options || {};
  // a sprite name is lowercase and hyphen separated, everything else is
  // rejected instead of being written into the markup
  const iconName = String(name).replace(/[^a-z0-9-]/g, '');
  const path = spriteIconPath(opts.sprite);
  if (!iconName || !path) { return ''; }

  const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
  svg.setAttribute('class', `s${opts.size || 18} icon-svg${opts.cssClass ? ` ${opts.cssClass}` : ''}`);
  if (opts.title) {
    const title = document.createElementNS('http://www.w3.org/2000/svg', 'title');
    title.textContent = opts.title;
    svg.appendChild(title);
  } else {
    svg.setAttribute('aria-hidden', 'true');
  }

  const use = document.createElementNS('http://www.w3.org/2000/svg', 'use');
  use.setAttribute('href', `${path}#icon--${iconName}`);
  svg.appendChild(use);

  return svg.outerHTML;
}

/* Render a select2 option for the Tabler icon picker: SVG sprite icon + name.
   The full sprite href is provided per option via data-href. */
/* exported formatIconOption */
function formatIconOption(icon) {
  if (icon.id === undefined || icon.id === '') {
    return icon.text;
  }

  const href = icon.element && icon.element.dataset ? icon.element.dataset.href : null;
  const span = document.createElement('span');
  if (href) {
    const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    svg.setAttribute('class', 's18 icon-svg');
    svg.setAttribute('aria-hidden', 'true');
    const use = document.createElementNS('http://www.w3.org/2000/svg', 'use');
    use.setAttribute('href', href);
    svg.appendChild(use);
    span.appendChild(svg);
    span.appendChild(document.createTextNode(` ${icon.text}`));
  } else {
    span.textContent = icon.text;
  }
  return span;
}

/* Use this instead of showTab from Redmine, because on tabs are supported for plugin settings */
/* exported showPluginSettingsTab */
/* global replaceInHistory */
function showPluginSettingsTab(name, url) {
  const tabContent = document.getElementById(`tab-content-${name}`);
  if (tabContent && tabContent.parentElement) {
    tabContent.parentElement.querySelectorAll('.tab-content').forEach(el => { el.style.display = 'none'; });
    tabContent.style.display = '';
  }

  const tab = document.getElementById(`tab-${name}`);
  if (tab) {
    const tabs = tab.closest('.tabs');
    if (tabs) {
      tabs.querySelectorAll('a').forEach(a => a.classList.remove('selected'));
    }
    tab.classList.add('selected');

    const form = tab.closest('form');
    if (form) {
      addTabToFromAction(form, name);
    }
  }

  replaceInHistory(url);
  return false;
}

function addTabToFromAction(form, name) {
  let action = form.getAttribute('action');
  if (!action) {
    return;
  }

  if (action.includes('tab=')) {
    action = action.replace(/([?&])(tab=)[^&#]*/, `$1$2${name}`);
  } else if (!action.includes('?')) {
    action = `${action}?tab=${name}`;
  } else if (!action.includes(name)) {
    action = `${action}&tab=${name}`;
  }

  form.setAttribute('action', action);
}

// Variable cheat-sheets. A form which advertises {%var%} placeholders renders
// a "show variables" link next to a hidden list of them:
//
//   em.info = link_to_show_variables
//   em.info.available-variables.toggle-variables data-insert-target='my_field'
//     ... links with class "var" ...
//
// Clicking the link reveals the list, clicking a variable inserts it. The
// target field is either named by data-insert-target, or - where the fields
// are dynamic, as in invoice lines or automation actions - it is the field
// with class "variable-value" the user edited last.
//
// Delegated on document, so forms replaced by ajax keep working. Loaded
// globally through additionals/_html_head, which is why every plugin gets this
// without an asset of its own.

// Inserts text where the cursor is, keeping the scroll position. Global,
// because views insert the answer of an ajax request the same way.
/* exported insertTextAtCaret */
function insertTextAtCaret(field, value) {
  if (!field) { return; }

  if (field.selectionStart === undefined) {
    field.value += value;
  } else {
    const start = field.selectionStart;
    const end = field.selectionEnd;
    const { scrollTop } = field;

    field.value = field.value.slice(0, start) + value + field.value.slice(end);
    field.selectionStart = start + value.length;
    field.selectionEnd = field.selectionStart;
    field.scrollTop = scrollTop;
  }

  field.focus();
}

(() => {
  let lastVarField = null;

  // focus does not bubble, so it is captured instead of delegated
  document.addEventListener('focus', (event) => {
    if (event.target.classList?.contains('variable-value')) { lastVarField = event.target; }
  }, true);

  document.addEventListener('click', (event) => {
    const link = event.target.closest('a.show-variables');
    if (!link) { return; }

    event.preventDefault();
    link.style.display = 'none';

    // an explicit target is needed where two lists share a parent
    const targetId = link.dataset.showTarget;
    const list = targetId
      ? document.getElementById(targetId)
      : link.parentElement?.parentElement?.querySelector('em.available-variables');

    // the list is hidden by the class, so dropping it is what reveals it
    list?.classList.remove('toggle-variables');
  });

  document.addEventListener('click', (event) => {
    const variable = event.target.closest('a.var');
    if (!variable) { return; }

    event.preventDefault();
    const targetId = variable.closest('[data-insert-target]')?.dataset.insertTarget;
    const field = targetId ? document.getElementById(targetId) : lastVarField;

    insertTextAtCaret(field, variable.innerHTML);
  });
})();

// Configuration of every mermaid diagram, whoever renders it: the additionals
// macros (mermaid_load.js) and, since Redmine 7.1, core for mermaid code
// blocks. Core loads the library on its own, without mermaid_load.js, so the
// configuration is attached to the library as soon as it is defined.
(() => {
  // theme, look and layout are only passed on when a theme sets them
  // (globalThis.mermaidTheme, ...), so mermaid's own per diagram defaults
  // (ELK layout, neo look, redux-color theme) apply otherwise. Lines are 1px
  // instead of redux-color's 2px, which crowd diagrams with many edges. A
  // diagram that needs different values sets them in its own front matter.
  function additionalsMermaidConfig() {
    const config = {
      maxTextSize: 500000,
      themeVariables: globalThis.mermaidThemeVariables ?? { strokeWidth: 1 },
      flowchart: {
        useMaxWidth: false,
      },
      gantt: {
        topAxis: true,
        weekday: 'monday',
      },
    };

    if (globalThis.mermaidTheme !== undefined) { config.theme = globalThis.mermaidTheme; }
    if (globalThis.mermaidLook !== undefined) { config.look = globalThis.mermaidLook; }
    if (globalThis.mermaidLayout !== undefined) { config.layout = globalThis.mermaidLayout; }

    return config;
  }

  const isPlainObject = value => value?.constructor === Object;

  // Sections like flowchart or themeVariables are merged as well, so options
  // passed for one of them keep the additionals values of the others.
  function mergeMermaidConfig(base, config) {
    const merged = { ...base, ...config };
    Object.keys(config).forEach((key) => {
      if (isPlainObject(base[key]) && isPlainObject(config[key])) { merged[key] = { ...base[key], ...config[key] }; }
    });
    return merged;
  }

  // Each mermaid.initialize call replaces the whole configuration, so every
  // call starts from the additionals configuration instead.
  // Returns true if the library was not wrapped before.
  function keepAdditionalsMermaidConfig(library) {
    if (typeof library?.initialize !== 'function' || library.initialize.withAdditionalsConfig) { return false; }

    const libraryInitialize = library.initialize;
    const initialize = (config = {}) => libraryInitialize.call(library, mergeMermaidConfig(additionalsMermaidConfig(), config));
    initialize.withAdditionalsConfig = true;
    library.initialize = initialize;
    return true;
  }

  // The mermaid bundle ends with globalThis["mermaid"] = ..., which lands in
  // the setter. It stays in place, as two scripts loading the library at the
  // same time (core and the macro detector of redmine_reporting) assign it
  // twice. Only the last one stays global and gets initialized by its loader,
  // but each one starts rendering all diagrams on window load, the earlier
  // one with mermaid's defaults. So every library is initialized right away
  // without starting on load; mermaid_load.js turns that on for the global one.
  let library = globalThis.mermaid;
  keepAdditionalsMermaidConfig(library);

  Object.defineProperty(globalThis, 'mermaid', {
    configurable: true,
    enumerable: true,
    get() { return library; },
    set(value) {
      if (keepAdditionalsMermaidConfig(value)) { value.initialize({ startOnLoad: false }); }
      library = value;
    },
  });
})();
