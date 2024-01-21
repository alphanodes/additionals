# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class CoreExtTest < Additionals::TestCase
  def test_strip_split_with_default_sep
    assert_equal ['me@localhost',
                  'you@localhost',
                  'invalid@localhost@me',
                  'others@localhost'],
                 'me@localhost,you@localhost, invalid@localhost@me , others@localhost'.strip_split
  end

  def test_strip_split_with_custom_sep
    assert_equal ['me@localhost', 'you@localhost'], 'me@localhost;you@localhost'.strip_split(';')
  end

  def test_strip_split_with_empty_string
    assert_kind_of Array, ''.strip_split
    assert_empty ''.strip_split
  end

  def test_to_list
    assert_equal 'me@localhost, you@localhost', ['me@localhost', 'you@localhost'].to_comma_list
  end

  def test_to_list_with_empty_array
    assert_equal '', [].to_comma_list
  end
end
