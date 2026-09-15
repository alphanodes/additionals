# Updating the bundled Mermaid library

`additionals` ships Mermaid's official browser bundle at `assets/javascripts/vendor/mermaid.min.js` (plus its `.map`). This guide explains how to update it to a new Mermaid release.

## Which file and why

Redmine loads classic `<script>` tags and expects a global `mermaid` object (see `assets/javascripts/mermaid_load.js` and the `_mermaid_min` entry in `app/services/additionals/library_registry.rb`).

The npm package provides exactly that as `dist/mermaid.min.js`: a single file IIFE that assigns `globalThis.mermaid`. Upstream builds it on purpose in `.esbuild/build.ts` next to `mermaid.tiny.min.js`, and it has been part of every release since 11.0.0 (only 10.0.0 was ESM-only). It is not the recommended entry point of the package (that is the ESM build), so check on every update that it is still there.

The official file is preferred over a bundle built by ourselves: upstream builds it from source with its tested dependency versions, a defined browser target (`es2024`, Safari/iOS 17.4) and `keepNames` for readable stack traces.

## What not to do

- **Do not** copy the bundle from `redmica_ui_extension`. `additionals` is usually ahead of it version-wise.
- **Do not** switch to `@mermaid-js/tiny`. It is roughly 40% smaller, but it drops Mindmap, Architecture, KaTeX and the ELK layout. The `{{mermaid()}}` wiki macro accepts arbitrary diagram types, so a silent loss of those is not acceptable for a library plugin.

## Update steps

Work in a scratch directory, not in the repository.

1. Download and unpack the release:

   ```shell
   npm pack mermaid@<version>
   tar xzf mermaid-<version>.tgz
   ```

2. Copy `package/dist/mermaid.min.js` and `package/dist/mermaid.min.js.map` into `assets/javascripts/vendor/`.

3. Bump the version references:
   - the Mermaid line in `README.md`
   - a new `CHANGELOG.md` entry: `- mermaid <version> support`

## Fallback: building the bundle

Only needed if a release no longer ships `dist/mermaid.min.js`. The options below reproduce upstream's IIFE build (see `.esbuild/util.ts` in the Mermaid repository):

```js
// entry.mjs
export { default } from 'mermaid';
```

```js
// build.mjs, run after: npm i mermaid@<version> esbuild
import * as esbuild from 'esbuild';

await esbuild.build({
  entryPoints: ['entry.mjs'],
  bundle: true,
  minify: true,
  keepNames: true,
  target: ['es2024', 'safari17.4', 'ios17.4'],
  format: 'iife',
  globalName: '__esbuild_esm_mermaid_nm.mermaid',
  banner: { js: '"use strict";' },
  footer: { js: 'globalThis["mermaid"] = globalThis.__esbuild_esm_mermaid_nm["mermaid"].default;' },
  sourcemap: 'external',
  legalComments: 'eof',
  outfile: 'mermaid.min.js',
});
```

Take the `target` list from `.build/common.ts` of the release being built.

## Theme, look and layout

`mermaid_load.js` passes `theme`, `look` and `layout` to `mermaid.initialize` only when a Redmine theme sets the matching global (`mermaidTheme`, `mermaidLook`, `mermaidLayout`). Since Mermaid 12 the defaults differ per diagram type (e.g. `redux-color` for flowcharts), and a global `theme` in `initialize` overrides all of them, so do not add a hardcoded theme there.

The one deliberate default is `themeVariables: { strokeWidth: 1 }` (unless a theme sets `mermaidThemeVariables`): `redux-color` draws 2px lines, which crowd diagrams with many edges. A diagram that needs different values sets them in its own front matter, as the workflow graph in `redmine_reporting` does.

## Verifying the update

- **The file is the IIFE build.** `dist/mermaid.min.js` exists, starts with `"use strict";var __esbuild_esm_mermaid_nm`, ends with `globalThis["mermaid"] = ...` and contains the new `version:"..."`. If it is missing or has another format, use the fallback build.
- **Smoke-test the global.** Loading the file must expose `globalThis.mermaid` with the same API surface as the previous bundle (`initialize`, `run`, `render`, `parse`, ...).
- **Render in a real browser.** Load `mermaid.min.js` + `mermaid_load.js` on a minimal page with `<pre class="mermaid">` diagrams (flowchart, sequence, gantt, mindmap, architecture, a KaTeX label) and confirm they render to SVGs without console errors.
- **Check whether gantt can switch to the new appearance.** Mermaid 12 keeps the old `default` theme for gantt. With `redux-color` the bars of the `redmine_reporting` roadmap (projects and version list, `display_type=roadmap`) are white on a near white background and hard to see. Render the roadmap with `theme: redux-color` in its front matter; once the bars are clearly visible, switch gantt to the new appearance.

## Committing

`additionals` is mirrored to a public GitHub repository, so the commit message uses **no** ticket id:

```text
mermaid <version> support
```
