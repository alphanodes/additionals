# Library Loader

`additionals` ships the JavaScript and CSS libraries of the plugin family once, in one version, and loads them only on pages that need them. `Additionals::LibraryRegistry` knows which files belong to which library, `additionals_library_load` puts them into the page, `AdditionalsHelpers.loadLibrary` loads them later in the browser.

## Libraries

| Name | Content |
| ---- | ------- |
| `chartjs` | Chart.js with the colorschemes plugin |
| `chartjs_meta` | `chartjs` with the datalabels and annotation plugins, the usual choice for charts |
| `chartjs_annotation`, `chartjs_colorschemes`, `chartjs_datalabels` | A single Chart.js plugin |
| `chartjs_matrix` | The matrix chart type of Chart.js |
| `chartjs_sankey`, `chartjs_treemap` | The sankey or treemap chart type of Chart.js, with `chartjs` |
| `dhtmlxgantt` | dhtmlxGantt with its styles |
| `mermaid` | mermaid with the loader for mermaid code blocks |
| `query_chart` | Styles of query chart blocks and their settings form |
| `select_fields` | The library behind the [select fields](select-fields.md) with its styles and the filter registry |
| `sortable` | SortableJS |

Versions are listed in the [README](../README.md#libraries). A name lists its files in loading order, a file required by several names is loaded once. Unknown names raise an `ArgumentError`, so a typo fails instead of loading nothing.

## Loading on the server

A view loads one or more libraries; every file is included at most once per response, also when several partials ask for it:

```slim
= additionals_library_load :chartjs_meta
= additionals_library_load %i[chartjs_meta sortable]
```

Dashboard blocks do not call the helper. They declare their libraries, and the dashboard loads those of all its blocks in the page head:

```ruby
async partial: 'dashboards/blocks/my_chart', libraries: %i[chartjs_meta]
```

Blocks that are added or saved without a page reload depend on this: their partial arrives by AJAX and cannot add files to the head.

## Loading in the browser

Where the page cannot know in advance whether a library is needed, e.g. a chart type that needs a plugin only with certain settings, the browser loads it on demand:

```js
await AdditionalsHelpers.loadLibrary('chartjs_treemap');
```

The promise resolves when all files are loaded, in their order. Files already in the page are skipped, a library is requested only once per page. The URLs of all libraries are in `ADDITIONALS_LIBRARIES`, which additionals writes into every page head. The chart controller loads the Chart.js plugins this way (see the [Chart Development Guide](charts.md)).

## Libraries of other plugins

A plugin registers its own files under a name of its own and then loads them like the built-in libraries:

```ruby
def setup
  Additionals::LibraryRegistry.register :reporting_counter,
                                        [Additionals::LibraryRegistry::Asset.new(type: :css,
                                                                                 path: 'reporting-counter',
                                                                                 plugin: 'redmine_reporting')]
end
```

* An entry is an `Asset` (`type` `:js` or `:css`, `path` below `assets/javascripts` or `assets/stylesheets` without extension, `plugin`) or the name of another library, e.g. `%i[chartjs_meta]` plus an own asset.
* Register in the `setup` of the plugin or in a `config.to_prepare` block, not once at boot. The registry is reloaded with the code in development and loses registrations made only once.
* A name of a built-in library raises an `ArgumentError`, registering the same name again replaces it.

This is the way to load a stylesheet that only some pages need: a `stylesheet_link_tag` in an async partial lands outside the head and is sometimes missing after a reload.

## Updating libraries

Libraries taken unchanged from an npm package are listed in `config/vendor_libraries.yml` with their version, the files copied from the package and their SHA-256. Two rake tasks for maintainers update them, an installation never downloads anything:

```shell
bundle exec rake redmine:additionals:vendor:outdated
bundle exec rake redmine:additionals:vendor:update NAME=chartjs,chartjs_annotation
bundle exec rake redmine:additionals:vendor:update NAME=mermaid VERSION=12.2.0
```

`update` checks the tarball against the integrity npm publishes, replaces the files and records the version in the manifest and in the libraries table of the README. A test fails when a listed file or a version in the README differs from the manifest, so a file changed by hand does not go unnoticed. Review the diff, test the pages using the library and add a CHANGELOG entry; a library with its own guide (mermaid: [Updating the bundled Mermaid library](updating-mermaid.md)) names it after the update.

The patched colorschemes plugin is not listed and is updated by hand.
