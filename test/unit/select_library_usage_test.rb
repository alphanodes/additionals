# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class SelectLibraryUsageTest < Additionals::TestCase
  def setup
    super
    @directory = Dir.mktmpdir
  end

  def teardown
    FileUtils.remove_entry @directory
    super
  end

  def test_finds_the_library_in_code_styles_and_tests
    write 'assets/javascripts/plugin_x.js', <<~JS
      $('#field').select2({ tags: true });
      $('#field').on('select2:select', () => {});
      $('#field').trigger('change.select2');
      if ($('#field').data('select2')) { select2Tag('field', {}); }
    JS
    write 'assets/stylesheets/plugin_x.css', ".box .select2-selection { color: red; }\n"
    write 'app/views/foo/_form.html.slim', "= additionals_select2_tag 'foo', nil, format_state: 'formatNameWithIcon'\n"
    write 'test/system_browser/foo_test.rb', "find('.select2-results__option').click\n"
    write 'app/views/foo/_body_bottom.html.slim', "javascript:\n  additionals_field_formats.push('foo');\n"

    assert_equal ['app/views/foo/_body_bottom.html.slim:2: former helper of additionals',
                  'app/views/foo/_form.html.slim:1: former helper of additionals',
                  'assets/javascripts/plugin_x.js:1: call or jQuery event of the library',
                  'assets/javascripts/plugin_x.js:2: event of the library',
                  'assets/javascripts/plugin_x.js:3: call or jQuery event of the library',
                  'assets/javascripts/plugin_x.js:4: data of the library',
                  'assets/stylesheets/plugin_x.css:1: CSS class of the library',
                  'test/system_browser/foo_test.rb:1: CSS class of the library'],
                 Additionals::SelectLibraryUsage.hits(@directory)
  end

  # The next library (Tom Select) and the former name of the library package
  # are no business of plugins either, also in further file types
  def test_finds_the_next_library_and_the_former_package_name
    write 'assets/javascripts/plugin_x.mjs', "new TomSelect(field, {});\nfield.tomselect.open();\n"
    write 'assets/stylesheets/plugin_x.scss', ".box .ts-control { color: red; }\n"
    write 'app/views/foo/_head.html.slim', "= additionals_library_load :select2\n"
    write 'assets/javascripts/plugin_y.js', "if (field.dataset['select2']) {}\n"

    assert_equal ['app/views/foo/_head.html.slim:1: former helper of additionals',
                  'assets/javascripts/plugin_x.mjs:1: call or class of the library',
                  'assets/javascripts/plugin_x.mjs:2: call or class of the library',
                  'assets/javascripts/plugin_y.js:1: data of the library',
                  'assets/stylesheets/plugin_x.scss:1: call or class of the library'],
                 Additionals::SelectLibraryUsage.hits(@directory)
  end

  # Only the files of the select fields in additionals know the library
  def test_additionals_knows_the_library_only_in_its_select_field_files
    allowed = %w[assets/javascripts/controllers/additionals_select_controller.js
                 assets/stylesheets/select2.css
                 test/global_system_test_helper.rb
                 test/javascript/controllers/additionals_select_controller.test.js
                 test/select_library_usage.rb
                 test/unit/select_library_usage_test.rb]
    files = Additionals::SelectLibraryUsage.hits(Redmine::Plugin.find(:additionals).directory).to_set { |hit| hit.split(':').first }

    assert_empty files - allowed
  end

  # Names that only mention the library are no use of it, bundled files are
  # not ours
  def test_ignores_names_and_bundled_libraries
    write 'app/helpers/foo_helper.rb', <<~RUBY
      def entries_for_select2 = render_grouped_users_with_select2(users)
      LIMIT = AdditionalsConf.select2_init_entries
      field = additionals_select_tag 'foo', nil, renderer: 'avatar'
    RUBY
    write 'assets/javascripts/vendor/select2.js', "$.fn.select2 = function () {};\n"
    write 'assets/javascripts/other.min.js', "$('#a').select2();\n"
    write 'docs/dev-guide.md', "We used .select2( once.\n"

    assert_empty Additionals::SelectLibraryUsage.hits(@directory)
  end

  private

  def write(path, content)
    file = File.join @directory, path
    FileUtils.mkdir_p File.dirname(file)
    File.write file, content
  end
end
