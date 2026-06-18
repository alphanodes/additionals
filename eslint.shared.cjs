// eslint.shared.cjs — shared ESLint flat-config builder for AlphaNodes Redmine
// plugins. This file is identical across all plugins and is distributed by
// `redmine_sync_node_linter_versions` (like .stylelintrc.json) — edit only the
// canonical source copy, never a synced copy.
//
// Each plugin's own eslint.config.cjs is a thin wrapper that calls this factory
// and injects its plugin-specific globals/ignores:
//
//   module.exports = require('./eslint.shared.cjs')({
//     ignores: ['assets/javascripts/vendor/**'],
//     controllerGlobals: { MyHelper: 'readonly' },
//     testGlobals: { MyTestGlobal: 'readonly' },
//   });
//
// ecmaVersion 2022: Redmine dropped IE11 in 5.0.0 (#34978), so modern syntax
// (optional chaining etc.) is safe even in directly-served classic scripts.
const js = require('@eslint/js');
const globals = require('globals');
const noJquery = require('eslint-plugin-no-jquery');
const stylistic = require('@stylistic/eslint-plugin');

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

  // stylistic / layout — handled by @stylistic (the core formatting rules are
  // deprecated in ESLint and slated for removal). Airbnb-aligned set.
  '@stylistic/indent': ['error', 2],
  '@stylistic/linebreak-style': ['error', 'unix'],
  '@stylistic/quotes': ['error', 'single'],
  '@stylistic/semi': ['error', 'always'],
  '@stylistic/comma-dangle': ['error', 'always-multiline'],
  '@stylistic/comma-spacing': 'error',
  '@stylistic/comma-style': 'error',
  '@stylistic/object-curly-spacing': ['error', 'always'],
  '@stylistic/array-bracket-spacing': ['error', 'never'],
  '@stylistic/space-in-parens': ['error', 'never'],
  '@stylistic/space-infix-ops': 'error',
  '@stylistic/space-before-blocks': 'error',
  '@stylistic/space-before-function-paren': ['error', { anonymous: 'always', named: 'never', asyncArrow: 'always' }],
  '@stylistic/keyword-spacing': 'error',
  '@stylistic/arrow-spacing': 'error',
  '@stylistic/key-spacing': 'error',
  '@stylistic/semi-spacing': 'error',
  '@stylistic/function-call-spacing': 'error',
  '@stylistic/brace-style': ['error', '1tbs', { allowSingleLine: true }],
  '@stylistic/quote-props': ['error', 'as-needed'],
  '@stylistic/operator-linebreak': 'error',
  '@stylistic/no-multiple-empty-lines': ['error', { max: 1, maxEOF: 0, maxBOF: 0 }],
  '@stylistic/no-trailing-spaces': 'error',
  '@stylistic/eol-last': 'error',
  '@stylistic/no-mixed-operators': 'error',
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

  // modernization guardrails — keep legacy patterns out (arguments, .apply,
  // Math.pow, Object() number parsing, non-Error promise rejects)
  'prefer-rest-params': 'error',
  'prefer-spread': 'error',
  'prefer-exponentiation-operator': 'error',
  'prefer-numeric-literals': 'error',
  'prefer-promise-reject-errors': 'error',

  // remove dead/useless constructs
  'no-useless-constructor': 'error',
  'no-useless-rename': 'error',
  'no-useless-computed-key': 'error',
  'no-useless-return': 'error',
  'no-useless-call': 'error',
  'no-lone-blocks': 'error',

  // additional correctness guardrails
  'array-callback-return': 'error',
  'no-unreachable-loop': 'error',
  'default-case-last': 'error',
  'no-unneeded-ternary': 'error',
  'no-template-curly-in-string': 'error',
  'no-unmodified-loop-condition': 'error',
  'no-undef-init': 'error',
};

// Build the plugin's flat-config array. All options are optional:
//   ignores           — ignore globs (e.g. minified/vendored files)
//   scriptGlobals     — extra globals for classic script files
//   controllerGlobals — extra globals for assets/javascripts/controllers/**
//   testGlobals       — extra globals for test/javascript/**
// The controller and test blocks are always emitted; their `files` patterns
// make them inert for plugins without those directories.
module.exports = function createEslintConfig(options = {}) {
  const {
    ignores,
    scriptGlobals = {},
    controllerGlobals = {},
    testGlobals = {},
  } = options;

  const config = [];

  if (ignores && ignores.length > 0) {
    config.push({ ignores });
  }

  config.push(js.configs.recommended);

  // Classic script files (IIFE, jQuery) — served directly to browsers.
  config.push({
    plugins: {
      'no-jquery': noJquery,
      '@stylistic': stylistic,
    },
    languageOptions: {
      ecmaVersion: 2022,
      sourceType: 'script',
      globals: {
        ...globals.browser,
        ...globals.jquery,
        ...scriptGlobals,
      },
    },
    rules: sharedRules,
  });

  // ES Module controllers (Stimulus)
  config.push({
    files: ['assets/javascripts/controllers/**/*.js'],
    languageOptions: {
      ecmaVersion: 2022,
      sourceType: 'module',
      globals: {
        ...globals.browser,
        ...globals.jquery,
        ...controllerGlobals,
      },
    },
    rules: sharedRules,
  });

  // Vitest test files — ES Modules in a jsdom + Node environment. The
  // browser+node union covers every plugin's test setup (globalThis, process,
  // __dirname, global, require, ... all come from globals.node), so wrappers
  // only inject their own named test helpers via testGlobals.
  config.push({
    files: ['test/javascript/**/*.js'],
    languageOptions: {
      ecmaVersion: 2022,
      sourceType: 'module',
      globals: {
        ...globals.browser,
        ...globals.node,
        ...testGlobals,
      },
    },
    rules: sharedRules,
  });

  return config;
};
