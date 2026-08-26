# Updating the bundled CodeMirror library

`additionals` ships CodeMirror 6 as a self-built browser bundle at
`assets/javascripts/vendor/codemirror.js`, requested through the `:codemirror`
package of `Additionals::LibraryRegistry`. It is used by `redmine_editor`.

## Why the bundle is self-built

CodeMirror 6 is published as ES modules only, split across a dozen packages.
Redmine loads classic `<script>` tags, so there is nothing to download. The
entry point `src/vendor/codemirror.js` imports what a plugin needs and exposes
it as the global `CodeMirror6`; esbuild bundles it into a single IIFE.

Unlike the Mermaid bundle this one has a build script in the repository:

```shell
yarn install
yarn build
```

## What not to do

- **Do not** import `@codemirror/lang-markdown` as a whole. It pulls in the
  HTML, JavaScript and CSS languages plus autocomplete to highlight embedded
  code, which is around 40 percent extra bundle size for something no plugin
  here needs. The markdown language is built on the same parser directly.
  Individual commands from that package (`insertNewlineContinueMarkup`,
  `deleteMarkupBackward`) tree-shake cleanly and cost about 4 KB.
- **Do not** add extensions to the global object speculatively. Every export
  is dead weight in every page that loads the bundle. Add what a plugin
  actually uses, when it uses it.

## Keeping the parser aligned with Redmine

The enabled parser extensions have to match Redmine's `PIPELINE_CONFIG` in
`lib/redmine/wiki_formatting/common_mark/formatter.rb`, otherwise the editor
highlights a syntax the server does not render, or misses one it does. `GFM`
covers table, strikethrough, tasklist and autolink. Footnotes and alerts are
rendered by the server but have no parser extension here, so they stay
unhighlighted - a missing highlight, never a broken document. Check this list
whenever Redmine changes its pipeline configuration.

## After updating

Run the plugin test suites that use the bundle (`redmine_editor`) and check a
Redmine page with a wiki toolbar in the browser: the bundle is not covered by
the Ruby tests, only its registry entry is.
