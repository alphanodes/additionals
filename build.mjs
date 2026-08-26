// Builds the ESM-only vendor libraries into classic scripts that Redmine can
// serve through Propshaft. Output is committed, so no npm install is needed on
// a customer installation. See docs/dev-guide.md.
import { build } from 'esbuild';

await build({
  entryPoints: ['src/vendor/codemirror.js'],
  outfile: 'assets/javascripts/vendor/codemirror.js',
  bundle: true,
  minify: true,
  format: 'iife',
  target: ['es2022'],
  legalComments: 'none',
  banner: { js: '/* CodeMirror 6 (MIT) - bundled for Redmine, built from src/vendor via `yarn build` */' },
});
