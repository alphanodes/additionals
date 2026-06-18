const js = require('@eslint/js');
const globals = require('globals');
const noJquery = require('eslint-plugin-no-jquery');

// Resolve the chained deprecated config from eslint-plugin-no-jquery
// since it uses legacy "extends" which is not supported in flat config.
function resolvePluginConfig(plugin, configName) {
  const config = plugin.configs[configName];
  let rules = {};
  if (config.extends) {
    const parentName = config.extends.replace('plugin:no-jquery/', '');
    rules = resolvePluginConfig(plugin, parentName);
  }
  return { ...rules, ...(config.rules || {}) };
}

const sharedRules = {
  ...resolvePluginConfig(noJquery, 'deprecated'),

  // stylistic
  indent: ['error', 2],
  'linebreak-style': ['error', 'unix'],
  quotes: ['error', 'single'],
  semi: ['error', 'always'],
  curly: 'error',
  'dot-notation': 'error',

  // modern JS
  'no-var': 'error',
  'prefer-const': 'error',
  'prefer-template': 'error',
  'prefer-arrow-callback': 'error',
  'prefer-destructuring': ['error', { object: true, array: false }],
  'object-shorthand': 'error',

  // best practices
  eqeqeq: 'error',
  radix: 'error',
  'no-eval': 'error',
  'no-implied-eval': 'error',
  'no-caller': 'error',
  'no-extend-native': 'error',
  'no-throw-literal': 'error',
  'no-self-compare': 'error',
  'no-constructor-return': 'error',
  'no-new-wrappers': 'error',
  'no-return-assign': 'error',
  'no-sequences': 'error',
};

module.exports = [
  {
    // Third-party libraries live in assets/javascripts/vendor/ and are not linted.
    // Everything else (own root scripts + controllers/) is linted by default, so
    // new own scripts can never be silently skipped.
    ignores: [
      'assets/javascripts/vendor/**',
    ],
  },
  js.configs.recommended,
  {
    plugins: {
      'no-jquery': noJquery,
    },
    languageOptions: {
      ecmaVersion: 2022,
      sourceType: 'script',
      globals: {
        ...globals.browser,
        ...globals.jquery,
      },
    },
    rules: sharedRules,
  },
  // ES Module controllers (Stimulus) — must come AFTER to override sourceType
  {
    files: ['assets/javascripts/controllers/**/*.js'],
    languageOptions: {
      ecmaVersion: 2022,
      sourceType: 'module',
      globals: {
        ...globals.browser,
        AdditionalsHelpers: 'readonly',
        sanitizeHTML: 'readonly',
      },
    },
    rules: sharedRules,
  },
  // Vitest test files — ES Modules with test globals
  {
    files: ['test/javascript/**/*.js'],
    languageOptions: {
      ecmaVersion: 2022,
      sourceType: 'module',
      globals: {
        ...globals.browser,
        __dirname: 'readonly',
        AdditionalsHelpers: 'readonly',
        buildSelect2Options: 'readonly',
        buildTagGroupName: 'readonly',
        createTag: 'readonly',
        formatFontawesomeText: 'readonly',
        formatNameWithIcon: 'readonly',
        globalThis: 'readonly',
        openExternalUrlsInTab: 'readonly',
        operatorByType: 'readonly',
        process: 'readonly',
        sanitizeHTML: 'readonly',
        sanitizeToId: 'readonly',
        setSelect2Filter: 'readonly',
        showPluginSettingsTab: 'readonly',
        updateSVGIcon: 'readonly',
      },
    },
    rules: sharedRules,
  },
];
