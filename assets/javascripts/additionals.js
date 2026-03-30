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

/* exported formatFontawesomeText */
function formatFontawesomeText(icon) {
  if (icon.id === undefined) {
    return icon.text;
  }

  const fa = icon.id.split('_');
  const span = document.createElement('span');
  span.innerHTML = `<i class="${fa[0]} fa-${fa[1]}"></i> ${icon.text}`;
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
