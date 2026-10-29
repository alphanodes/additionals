/* global jsToolBar */

/* Buttons of plugins in the wiki toolbar, for the jsToolBar of Redmine 7.0 and
   the server rendered toolbar of Redmine 7.1 (https://www.redmine.org/issues/43259)
   alike. The new toolbar offers no way to add buttons, so a registered button is
   put into every toolbar of the page as button.jstb_<name>: the markup and the
   classes of the toolbar stay the same in both, and so does the styling of the
   buttons by their class. Toolbars added later (AJAX, modals, dashboard blocks)
   get the buttons as well.

   AdditionalsWikiToolbar.register(name, {
     title,                 // tooltip and text of the button
     onClick(context),      // context: textarea, button, wrapSelection(prefix, suffix), replaceSelection(text)
     available(textarea),   // optional: false leaves the toolbar of this textarea without the button
   })

   An editor of its own (the visual editor) offers the same buttons by
   definitions() and runs them with contextFor(textarea, button). */
window.AdditionalsWikiToolbar = (() => {
  const buttons = new Map();
  let observer = null;

  // The textarea of a toolbar: named by the server rendered toolbar, inside
  // the editor of the jsToolBar
  function textareaOf(toolbar) {
    const block = toolbar.closest('.jstBlock');
    const fieldId = block ? block.dataset.wikiToolbarFieldIdValue : null;
    if (fieldId) { return document.getElementById(fieldId); }

    const editor = toolbar.closest('.jstEditor') || (block ? block.querySelector('.jstEditor') : null);
    return editor ? editor.querySelector('textarea') : null;
  }

  // Wraps the selection like the buttons of core do (encloseSelection of both
  // toolbars): a space keeps it apart from a word right before or after it, a
  // space at the end of the selection goes behind the suffix, and the cursor
  // ends up behind what was inserted, or behind the prefix without a
  // selection. The input event tells the preview and the warning about unsaved
  // changes.
  function wrapSelection(textarea, prefix, suffix) {
    const from = textarea.selectionStart;
    const to = textarea.selectionEnd;
    let selected = textarea.value.substring(from, to);
    let before = prefix;
    let after = suffix;

    if (from > 0 && /\S/.test(textarea.value.charAt(from - 1))) { before = ` ${before}`; }
    if (/\S/.test(textarea.value.charAt(to))) { after = `${after} `; }
    if (selected.endsWith(' ')) {
      selected = selected.slice(0, -1);
      after = `${after} `;
    }

    const inserted = `${before}${selected}${after}`;
    const caret = selected ? from + inserted.length : from + before.length;

    textarea.focus();
    textarea.setRangeText(inserted, from, to, 'end');
    textarea.setSelectionRange(caret, caret);
    textarea.dispatchEvent(new Event('input', { bubbles: true }));
  }

  // Puts the text in place of the selection, the cursor behind it
  function replaceSelection(textarea, text) {
    textarea.focus();
    textarea.setRangeText(text, textarea.selectionStart, textarea.selectionEnd, 'end');
    textarea.dispatchEvent(new Event('input', { bubbles: true }));
  }

  function contextFor(textarea, button) {
    return {
      textarea,
      button,
      wrapSelection: (prefix, suffix) => wrapSelection(textarea, prefix, suffix),
      replaceSelection: (text) => replaceSelection(textarea, text),
    };
  }

  function addButton(toolbar, name, definition) {
    if (toolbar.querySelector(`.jstb_${name}`)) { return; }

    const textarea = textareaOf(toolbar);
    if (!textarea || (definition.available && !definition.available(textarea))) { return; }

    const button = document.createElement('button');
    button.type = 'button';
    button.className = `jstb_${name}`;
    button.title = definition.title;
    button.tabIndex = 200;
    const label = document.createElement('span');
    label.textContent = definition.title;
    button.appendChild(label);
    button.addEventListener('click', (event) => {
      event.preventDefault();
      definition.onClick(contextFor(textarea, button));
    });
    // In front of the help, which closes the toolbar
    toolbar.insertBefore(button, toolbar.querySelector('.jstb_help'));
  }

  function decorate(toolbar) {
    buttons.forEach((definition, name) => addButton(toolbar, name, definition));
  }

  function decorateAll(root) {
    if (root.matches && root.matches('.jstElements')) { decorate(root); }
    if (root.querySelectorAll) { root.querySelectorAll('.jstElements').forEach(decorate); }
  }

  // Toolbars drawn later, and toolbars whose buttons are drawn again
  function observe() {
    if (observer || typeof MutationObserver === 'undefined') { return; }

    observer = new MutationObserver((mutations) => {
      mutations.forEach((mutation) => {
        mutation.addedNodes.forEach((node) => {
          if (node.nodeType !== Node.ELEMENT_NODE) { return; }

          const toolbar = node.closest('.jstElements');
          if (toolbar) {
            decorate(toolbar);
          } else {
            decorateAll(node);
          }
        });
      });
    });
    observer.observe(document.documentElement, { childList: true, subtree: true });
  }

  // TODO(Redmine 7.0 EOL): drop, the jsToolBar draws registered elements itself
  // and the visual editor takes them from its prototype. A button for some
  // textareas only stays out of it, it goes in by decorate. Called on register
  // and again on start: a plugin head registers before :header_tags loads the
  // jsToolBar.
  function addToJsToolBar(name, definition) {
    if (typeof jsToolBar === 'undefined' || definition.available || jsToolBar.prototype.elements[name]) { return; }

    jsToolBar.prototype.elements[name] = {
      type: 'button',
      title: definition.title,
      fn: {
        wiki() {
          const toolbar = this;
          definition.onClick({
            textarea: toolbar.textarea,
            button: toolbar.toolNodes[name],
            wrapSelection: (prefix, suffix) => toolbar.encloseSelection(prefix, suffix),
            replaceSelection: (text) => toolbar.encloseSelection('', '', () => text),
          });
        },
      },
    };
  }

  function start() {
    buttons.forEach((definition, name) => addToJsToolBar(name, definition));
    decorateAll(document);
    observe();
  }

  function register(name, definition) {
    buttons.set(name, definition);
    addToJsToolBar(name, definition);

    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', start, { once: true });
    } else {
      start();
    }
  }

  // The registered buttons as [name, definition], in the order of registering
  function definitions() {
    return Array.from(buttons.entries());
  }

  return {
    register, definitions, contextFor, wrapSelection, replaceSelection, textareaOf,
  };
})();
