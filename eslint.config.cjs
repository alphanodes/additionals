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

module.exports = [
  {
    // Ignore vendor/minified files (migrated from .eslintignore)
    ignores: [
      'assets/javascripts/*.js',
      '!assets/javascripts/additionals*.js',
      '!assets/javascripts/clipboard_feedback.js',
      '!assets/javascripts/mermaid_load.js',
      '!assets/javascripts/select2_helpers.js',
      '!assets/javascripts/sticky_header_goto_top.js',
    ],
  },
  js.configs.recommended,
  {
    plugins: {
      'no-jquery': noJquery,
    },
    languageOptions: {
      ecmaVersion: 2019,
      sourceType: 'script',
      globals: {
        ...globals.browser,
        ...globals.jquery,
      },
    },
    rules: {
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
    },
  },
];
