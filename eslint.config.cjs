// Plugin-specific ESLint config. The shared rules/blocks live in
// eslint.shared.cjs (synced across plugins); here we only inject this plugin's
// vendor ignore and the globals its controllers and Vitest tests rely on.
// Third-party libraries live in assets/javascripts/vendor/ and are not linted;
// everything else (own root scripts + controllers/) is linted by default.
module.exports = require('./eslint.shared.cjs')({
  ignores: ['assets/javascripts/vendor/**'],
  controllerGlobals: {
    AdditionalsHelpers: 'readonly',
    escapeHtml: 'readonly',
    sanitizeHTML: 'readonly',
  },
  testGlobals: {
    AdditionalsHelpers: 'readonly',
    escapeHtml: 'readonly',
    initTopMenuDropdown: 'readonly',
    openExternalUrlsInTab: 'readonly',
    sanitizeHTML: 'readonly',
    spriteIcon: 'readonly',
    spriteIconPath: 'readonly',
    showPluginSettingsTab: 'readonly',
    updateSVGIcon: 'readonly',
  },
});
