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
| `placeholder` | Shown in an empty field of a form, e.g. what is used without the setting; locale key, text or lambda |
| `values` | Allowed values of `enum` and `list`, plain or `[label, value]` |
| `offered` | The allowed values a form offers for the other values; others stay valid and fall back where they are read |
| `default` | Value read for a missing or blank setting, not stored; a boolean without one reads as `false` |
| `required` | Blank is an error (only while the setting applies); with a `default` only a value given blank, a missing one reads the default |
| `min`, `max` | Bounds of numbers |
| `if` | Whether the setting exists in the context at all, otherwise it counts as an unknown key |
| `applies` | Whether the setting applies to the other values |
| `field` | Partial of its field in a form built from the settings (dashboard blocks), for a setting the fields of the types cannot show |
| `secret` | A token, key or password: `describe` leaves out its value, a form built from the settings never fills it in |

Dashboard blocks declare these rules as methods instead of lambdas (see [Settings](dashboards.md#settings)). Lambdas get the schema: `schema[:key]` reads another setting (typed, with its default), `schema.context` the context it was built with.

## Reading Values

```ruby
schema = Additionals::SettingsSchema.new DEFINITIONS, params[:settings].to_unsafe_h, project: @project
schema.valid?        # validates the values
schema.errors        # => { max_entries: ['must be less than or equal to 100'] }
schema.full_messages # => ['Maximum entries must be less than or equal to 100']
schema.settings      # values to store, declared keys only
schema.ignored_keys  # => [:chart], unknown keys a program sent
schema[:max_entries] # => 10, typed and with its default
schema.values        # => given and stored values as stored, e.g. to build an object that knows the rules
schema.describe      # => [{ key: :url, type: :string, label: 'URL', required: true, applies: true }, ...]
```

Some rules to know:

- **Stored as forms send them:** booleans `"1"`/`"0"`, numbers as strings, blank means none. Code reading the stored settings works unchanged, a program may still send `true` or `10`.
- **Stored numbers out of bounds read as default:** a value stored before its bounds were declared does not reach the reader.
- **Invalid is rejected, not applicable is kept:** a value outside `values` or `min`/`max` is an error even if the setting does not apply. A setting that does not apply (`applies`) is kept, so a form switching back restores it, and it is not required.
- **Rules belong to the model:** lambdas ask the object that already knows a rule instead of restating it, so subclasses overriding it are covered.

## Options of a Query Class

Core describes filters, columns and display types itself. Options a plugin adds on top (stored in the serialized `options` of the query or an associated record, e.g. the counter box of redmine_reporting) are declared on the query, so programs (`list_query_options`, `save_query` of redmine_ai) can list and set them like the query form. A plugin extends three methods of `Query` with `super`:

```ruby
def query_options_definitions
  super.merge color_schema: { type: :enum, label: :label_issue_board_color_based_on }
end

# The stored values as the form sends them
def query_option_values
  super.merge color_schema: reporting_query_setting&.color_schema
end

# The params of the form for the values, read by build_from_params
def query_option_params(values)
  super.merge color_schema: values[:color_schema]
end

def query_option_color_schema_applies?(_schema) = display_type == 'task_board'
def query_option_color_schema_values(_schema) = [[l(:label_tracker), 'tracker'], ...]
```

Rules are methods named `query_option_<key>_<rule>` (`available?`, `applies?`, `values`, `offered`, `default`, `label`), `SettingsSchema.with_rule_methods` finds them like those of dashboard blocks. `query_options_schema(values)` checks given values, completed by the stored ones. Writing goes through `build_from_params` with `query_option_params`, so the validations of the query run as with the form; a program sends the stored values of options it does not change, the form sends them all with every save.
