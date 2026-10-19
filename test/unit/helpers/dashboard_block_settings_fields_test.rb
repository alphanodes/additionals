# frozen_string_literal: true

require File.expand_path '../../../test_helper', __FILE__

# The settings form of a block built from its declared settings: a field per
# type, filled with the stored values, which the schema reads back unchanged
class DashboardBlockSettingsFieldsTest < Additionals::HelperTest
  STORED = { max_entries: '20', ratio: '1.5', with_closed: '1', title: 'Latest', text: "Line 1\nLine 2",
             sort_by: 'date', interval: 'month' }.freeze

  def setup
    super
    User.current = users :users_001
    @redmine_view = build_redmine_view WelcomeController
  end

  def test_integer_is_a_number_field_with_the_stored_value
    assert_equal '20', field('input[type=number][name="settings[test][max_entries]"]')['value']
  end

  def test_integer_without_stored_value_shows_the_default
    assert_equal '10', field('input[name="settings[test][max_entries]"]', stored: {})['value']
  end

  def test_integer_has_the_bounds_of_the_setting
    input = field 'input[name="settings[test][max_entries]"]'

    assert_equal %w[1 50], [input['min'], input['max']]
  end

  def test_float_allows_decimals
    assert_equal 'any', field('input[type=number][name="settings[test][ratio]"]')['step']
  end

  def test_boolean_is_a_checked_checkbox_if_on
    assert field('input[type=checkbox][name="settings[test][with_closed]"]').key?('checked')
  end

  def test_boolean_sends_off_if_not_checked
    assert_equal '0', field('input[type=hidden][name="settings[test][with_closed]"]')['value']
  end

  def test_string_is_a_text_field_with_the_stored_value
    assert_equal 'Latest', field('input[type=text][name="settings[test][title]"]')['value']
  end

  def test_text_is_a_text_area_with_the_stored_value
    assert_equal "Line 1\nLine 2", field('textarea[name="settings[test][text]"]').text.delete_prefix("\n")
  end

  def test_enum_offers_the_offered_values_and_the_stored_one
    assert_equal ['', 'name', 'date'], fields('select[name="settings[test][sort_by]"] option').pluck('value')
  end

  def test_enum_selects_the_stored_value
    assert_equal 'date', field('select[name="settings[test][sort_by]"] option[selected]')['value']
  end

  def test_required_setting_is_marked
    assert field('label[for="settings_test_title"] span.required')
  end

  def test_label_of_the_setting
    assert_equal I18n.t(:label_max_entries), field('label[for="settings_test_max_entries"]').text
  end

  def test_info_of_the_setting
    assert_equal I18n.t(:label_sort), field('em.info').text
  end

  def test_setting_not_available_here_has_no_field
    assert_nil field('[name="settings[test][only_on_projects]"]')
  end

  # Not sent, so the stored value is kept
  def test_setting_that_does_not_apply_has_no_field
    assert_nil field('[name="settings[test][compact]"]')
  end

  def test_enum_with_a_default_offers_no_blank_value
    assert_equal %w[week month], fields('select[name="settings[test][interval]"] option').pluck('value')
  end

  def test_setting_without_field_needs_a_form_of_the_block
    block_class = Class.new(DashboardBlocks::Base) { setting :ids, type: :list, label: :label_issue_plural }

    assert_raises ArgumentError do
      @redmine_view.dashboard_block_settings_fields block_class.new(DashboardContentWelcome.new), 'test'
    end
  end

  # What the form sends is what was stored
  def test_sent_form_is_read_back_as_stored
    block = test_block STORED
    schema = Additionals::SettingsSchema.new block.declared_settings, sent_values(rendered(block))

    assert_equal STORED, schema.settings
  end

  private

  def test_block(stored)
    block_class = Class.new DashboardBlocks::Base do
      setting :max_entries, type: :integer, label: :label_max_entries, min: 1, max: 50, default: 10
      setting :ratio, type: :float, label: :field_estimated_hours
      setting :with_closed, type: :boolean, label: :label_closed_issues_plural
      setting :title, type: :string, label: :field_title, required: true
      setting :text, type: :text, label: :field_description
      setting :sort_by, type: :enum, label: :label_sort_by, info: :label_sort,
                        values: [%w[Name name], %w[Date date], %w[Size size]], offered: %w[name]
      setting :only_on_projects, type: :boolean, label: :field_project
      setting :compact, type: :boolean, label: :label_compact
      setting :interval, type: :enum, label: :label_chart_interval, values: %w[week month], default: 'week'

      private

      def compact_applies?(_schema)
        false
      end

      def only_on_projects_available?(_schema)
        project.present?
      end
    end
    block_class.new DashboardContentWelcome.new, settings: stored
  end

  def rendered(block)
    Nokogiri::HTML5.fragment @redmine_view.dashboard_block_settings_fields(block, 'test')
  end

  def field(css, stored: STORED)
    rendered(test_block(stored)).at_css css
  end

  def fields(css)
    rendered(test_block(STORED)).css css
  end

  # The values a browser sends, the last of a name wins like with Rack
  def sent_values(html)
    html.css('[name^="settings[test]"]').each_with_object({}) do |element, values|
      key = element['name'][/\[(\w+)\]\z/, 1].to_sym
      case element.name
      when 'select'
        values[key] = element.at_css('option[selected]')&.[]('value').to_s
      when 'textarea'
        values[key] = element.text.delete_prefix "\n"
      else
        values[key] = element['value'] unless element['type'] == 'checkbox' && !element.key?('checked')
      end
    end
  end
end
