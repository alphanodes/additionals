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
