# Settings Schema

`Additionals::SettingsSchema` declares settings as data: keys with their type and rules, read with values in a context. It casts what forms send, validates with errors per key and describes the settings for programmatic clients (AI or MCP tools). Dashboard blocks use it for their settings (see [Declared Settings](dashboards.md#declared-settings)); query classes can describe their own options with it.

## Declaring Settings

```ruby
DEFINITIONS = {
  url: { type: :string, label: :field_url, required: true },
  max_entries: { type: :integer, label: :label_max_entries, min: 1, max: 100, default: 10 },
  query_id: { type: :enum, label: :label_query,
              values: ->(schema) { IssueQuery.visible.map { |query| [query.name, query.id.to_s] } } },
  interval: { type: :enum, values: %w[week month], applies: ->(schema) { schema[:group_by] == 'start_date' } }
}.freeze
```

| Option | Description |
| ------ | ----------- |
| `type` | `string`, `text`, `integer`, `float`, `boolean`, `enum` or `list` |
| `label`, `info` | Locale key, text or lambda; use the keys of the settings form |
| `values` | Allowed values of `enum` and `list`, plain or `[label, value]` |
| `default` | Value read for a missing or blank setting, not stored |
| `required` | Blank is an error (only while the setting applies) |
| `min`, `max` | Bounds of numbers |
| `if` | Whether the setting exists in the context at all, otherwise it counts as an unknown key |
| `applies` | Whether the setting applies to the other values |

Lambdas get the schema: `schema[:key]` reads another setting (typed, with its default), `schema.context` the context it was built with.

## Reading Values

```ruby
schema = Additionals::SettingsSchema.new DEFINITIONS, params[:settings].to_unsafe_h, project: @project
schema.valid?        # validates the values
schema.errors        # => { max_entries: ['must be less than or equal to 100'] }
schema.full_messages # => ['Maximum entries must be less than or equal to 100']
schema.settings      # values to store, declared keys only
schema.ignored_keys  # => [:chart], unknown keys a program sent
schema[:max_entries] # => 10, typed and with its default
schema.describe      # => [{ key: :url, type: :string, label: 'URL', required: true, applies: true }, ...]
```

Some rules to know:

- **Stored as forms send them:** booleans `"1"`/`"0"`, numbers as strings, blank means none. Code reading the stored settings works unchanged, a program may still send `true` or `10`.
- **Invalid is rejected, not applicable is kept:** a value outside `values` or `min`/`max` is an error even if the setting does not apply. A setting that does not apply (`applies`) is kept, so a form switching back restores it, and it is not required.
- **Rules belong to the model:** lambdas ask the object that already knows a rule instead of restating it, so subclasses overriding it are covered.

## Options of a Query Class

Core describes filters, columns and display types itself. Options a plugin adds on top (stored in the serialized `options` of the query or an associated record) can be declared the same way, with the query as context:

```ruby
BOARD_OPTIONS = {
  board_statuses: { type: :list, label: :field_status,
                    values: ->(schema) { IssueStatus.sorted.map { |status| [status.name, status.id.to_s] } },
                    applies: ->(schema) { schema.context[:query].display_type == 'board' } }
}.freeze

def board_options_schema(values = options[:board_options] || {})
  Additionals::SettingsSchema.new BOARD_OPTIONS, values, query: self
end
```

The query decides where the values live and when they are written, e.g. in `build_from_params`.
