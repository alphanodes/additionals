# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class LocalizedErrorTest < Additionals::TestCase
  # The other tests name the case by its key, so this one has to prove that the
  # key still becomes a sentence - in the language of whoever reads it.
  def test_the_message_is_built_when_it_is_read
    error = Additionals::LocalizedError.new :error_field_template_unknown_placeholder, name: 'Nope'

    assert_equal 'Unknown placeholder: Nope', error.to_s
    I18n.with_locale :de do
      assert_equal 'Unbekannter Platzhalter: Nope', error.to_s
    end
  end

  def test_a_message_without_parameters
    error = Additionals::LocalizedError.new :errors_no_or_invalid_arguments

    assert_equal 'No or invalid arguments', error.to_s
    assert_empty error.params
  end

  def test_it_is_rescued_as_a_standard_error
    assert_raises StandardError do
      raise Additionals::LocalizedError, :errors_no_or_invalid_arguments
    end
  end
end
