// Plugin-specific ESLint config. The shared rules/blocks live in
// eslint.shared.cjs (synced across plugins); here we only inject this plugin's
// vendor ignore and the globals its controllers and Vitest tests rely on.
// Third-party libraries live in assets/javascripts/vendor/ and are not linted;
// everything else (own root scripts + controllers/) is linted by default.
module.exports = require('./eslint.shared.cjs')({
  ignores: ['assets/javascripts/vendor/**'],
  controllerGlobals: {
    AdditionalsHelpers: 'readonly',
    sanitizeHTML: 'readonly',
  },
  testGlobals: {
    AdditionalsHelpers: 'readonly',
    buildSelect2Options: 'readonly',
    buildTagGroupName: 'readonly',
    createTag: 'readonly',
    formatFontawesomeText: 'readonly',
    formatNameWithIcon: 'readonly',
    initTopMenuDropdown: 'readonly',
    openExternalUrlsInTab: 'readonly',
    operatorByType: 'readonly',
    sanitizeHTML: 'readonly',
    sanitizeToId: 'readonly',
    setSelect2Filter: 'readonly',
    showPluginSettingsTab: 'readonly',
    updateSVGIcon: 'readonly',
  },
});
