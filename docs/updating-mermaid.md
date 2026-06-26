# Updating the bundled Mermaid library

`additionals` ships Mermaid as a self-built browser bundle at
`assets/javascripts/vendor/mermaid.min.js` (plus its `.map`). This guide
explains how to update it to a new Mermaid release.

## Why the bundle is self-built

Since v10 Mermaid only publishes an ESM distribution (`dist/chunks/*.mjs`).
Redmine, however, loads classic `<script>` tags and expects a global
`mermaid` object (see `assets/javascripts/mermaid_load.js` and the
`_mermaid_min` entry in `app/services/additionals/library_registry.rb`).

There is no prebuilt browser file to download and no build script in the
repository. We therefore bundle the ESM entry point into a single IIFE with
esbuild and expose it as a global. This is a deliberate, recurring manual
step on every Mermaid upgrade.

## What not to do

- **Do not** copy the bundle from `redmica_ui_extension`. It uses the same
  build method, but `additionals` is usually ahead of it version-wise.
- **Do not** download `dist/mermaid.min.js` from a CDN/npm. It no longer
  exists; the published dist is ESM-only and split into chunks.
- **Do not** switch to `@mermaid-js/tiny`. It is a ready-made browser bundle
  (no self-build) and roughly 40% smaller, but it drops Mindmap, Architecture
  and KaTeX diagrams. The `{{mermaid()}}` wiki macro accepts arbitrary diagram
  types, so a silent loss of those is not acceptable for a library plugin.

## Build steps

The toolchain (Node + esbuild) is available locally. Work in a scratch
directory, not in the repository.

1. Create the entry point and build script:

   ```js
   // entry.mjs
   export { default } from 'mermaid';
   ```

   ```js
   // build.mjs - esbuild JS API (the CLI flags are identical)
   import * as esbuild from 'esbuild';

   await esbuild.build({
     entryPoints: ['entry.mjs'],
     bundle: true,
     minify: true,
     format: 'iife',
     globalName: '__esbuild_esm_mermaid_nm.mermaid',
     banner: { js: '"use strict";' },
     footer: { js: 'globalThis["mermaid"] = globalThis.__esbuild_esm_mermaid_nm["mermaid"].default;' },
     sourcemap: 'external',
     legalComments: 'eof',
     outfile: 'mermaid.min.js',
   });
   ```

2. Install the target version and build:

   ```shell
   npm i mermaid@<version> esbuild
   node build.mjs
   ```

3. Strip the single newline esbuild inserts after the `"use strict";` banner.
   The existing format is `"use strict";var ...` with no line break.

4. Copy `mermaid.min.js` and `mermaid.min.js.map` into
   `assets/javascripts/vendor/`.

5. Bump the version references:
   - the Mermaid line in `README.md`
   - a new `CHANGELOG.md` entry: `- mermaid <version> support`

## Verifying the build

Before trusting a new build, confirm the build config still matches the
established format:

- **Reproduce the current version first.** Build the version that is already
  checked in and compare it structurally against the committed file: header
  (`"use strict";var __esbuild_esm_mermaid_nm...`), footer
  (`globalThis["mermaid"] = ...`), the embedded `version:"..."`, an external
  `.map` (no `sourceMappingURL` comment in the `.js`), and the EOF legal
  comments block. Variable names and exact byte size differ between esbuild
  versions; the structure must match.
- **Smoke-test the global.** Loading the IIFE must expose `globalThis.mermaid`
  with the same API surface as the previous bundle (`initialize`, `run`,
  `render`, `parse`, ...).
- **Render in a real browser.** Load `mermaid.min.js` + `mermaid_load.js` on a
  minimal page with a `<pre class="mermaid">` diagram and confirm it renders to
  an SVG without `renderMermaidMacro` console errors.

## Committing

`additionals` is mirrored to a public GitHub repository, so the commit message
uses **no** ticket id:

```text
mermaid <version> support
```
