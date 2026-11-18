# frozen_string_literal: true

require File.expand_path '../../../test_helper', __FILE__

class FieldTemplateBlockTest < Additionals::TestCase
  def test_finds_the_fenced_block_of_the_language_in_common_mark
    text = <<~TEXT
      The line of a list:

      ```ruby
      puts 1
      ```

      ~~~~ Issue_List
      - {%subject%}
      ```
      still the template
      ~~~~

      The end.
    TEXT

    with_settings text_formatting: 'common_mark' do
      assert_equal "- {%subject%}\n```\nstill the template", find(text)
    end
  end

  # as in CommonMark, an unclosed fence runs to the end of the text
  def test_reads_an_unclosed_fence_to_the_end
    with_settings text_formatting: 'common_mark' do
      assert_equal '- {%subject%}', find("```issue_list\n- {%subject%}\n")
    end
  end

  # The rules of CommonMark which decide where a block begins and ends, and
  # the line endings of the wiki form
  def test_follows_the_fence_rules_of_common_mark
    cases = { "```issue_list\r\n- A\r\n```\r\n" => '- A',
              "````issue_list\n- A\n```\n- B\n````" => "- A\n```\n- B",
              "  ```issue_list\n  - A\n    - B\n  ```" => "- A\n  - B",
              "    ```issue_list\n- A\n```" => nil,
              "```issue_list `x`\n- A\n```" => nil }

    with_settings text_formatting: 'common_mark' do
      cases.each do |text, template|
        template.nil? ? assert_nil(find(text), text) : assert_equal(template, find(text).delete("\r"), text)
      end
    end
  end

  def test_finds_the_code_block_of_the_language_in_textile
    text = %(h2. Template\n\n<pre><code class="issue_list">\n* {%subject%}\n</code></pre>\n\n<pre><code class="ruby">1</code></pre>)

    with_settings text_formatting: 'textile' do
      assert_equal '* {%subject%}', find(text)
    end
  end

  # Only a block of the text format is a code block
  def test_returns_nil_without_a_block_of_the_language
    with_settings text_formatting: 'common_mark' do
      assert_nil find("```ruby\nputs 1\n```")
      assert_nil find(%(<pre><code class="issue_list">- {%subject%}</code></pre>))
      assert_nil find('')
    end
  end

  def test_raises_for_more_than_one_block_of_the_language
    with_settings text_formatting: 'common_mark' do
      error = assert_raises Additionals::FieldTemplate::Error do
        find "```issue_list\n- A\n```\n\n```issue_list\n- B\n```"
      end

      assert_equal :error_field_template_block_ambiguous, error.key
      assert_equal({ language: 'issue_list' }, error.params)
    end
  end

  private

  def find(text)
    Additionals::FieldTemplateBlock.find text, 'issue_list'
  end
end
