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

  const text = opt.name_with_icon !== undefined ? opt.name_with_icon : opt.text;
  const span = document.createElement('span');
  span.innerHTML = text;
  return span;
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
// globally through additionals/_html_head, which is why every plugin gets
// this without an asset of its own.
jQuery(($) => {
  // Inserts text where the cursor is, keeping the scroll position.
  $.fn.insertTextAtCaret = function (value) {
    return this.each(function () {
      if (this.selectionStart === undefined) {
        this.value += value;
      } else {
        const start = this.selectionStart;
        const end = this.selectionEnd;
        const { scrollTop } = this;

        this.value = this.value.slice(0, start) + value + this.value.slice(end);
        this.selectionStart = start + value.length;
        this.selectionEnd = this.selectionStart;
        this.scrollTop = scrollTop;
      }
      this.focus();
    });
  };

  let lastVarField = null;

  $(document).on('focus', '.variable-value', function () {
    lastVarField = this;
  });

  $(document).on('click', 'a.show-variables', function (event) {
    event.preventDefault();
    const link = $(this);
    link.hide();

    // an explicit target is needed where two lists share a parent
    const targetId = link.data('show-target');
    if (targetId) {
      $(`#${targetId}`).show();
    } else {
      link.parent().siblings('em.available-variables').show();
    }
  });

  $(document).on('click', 'a.var', function (event) {
    event.preventDefault();
    const targetId = $(this).closest('[data-insert-target]').data('insert-target');
    const field = targetId ? $(`#${targetId}`) : $(lastVarField);
    if (!field.length) { return; }

    field.insertTextAtCaret($(this).html());
  });
});
