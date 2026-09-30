# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class AdditionalsTest < Additionals::TestCase
  include Redmine::I18n

  def setup
    prepare_tests
  end

  def test_settings
    assert_raises NoMethodError do
      Additionals.settings[:open_external_urls]
    end
  end

  def test_setting
    assert_equal 'Don\'t forget to define acceptance criteria!',
                 Additionals.setting(:new_ticket_message)
    assert Additionals.setting?(:open_external_urls)
    assert_nil Additionals.setting(:no_existing_key)
  end

  def test_setting_bool
    assert Additionals.setting?(:open_external_urls)
    assert_not Additionals.setting?(:add_go_to_top)
  end

  def test_split_ids
    assert_equal [1, 2, 3], Additionals.split_ids('1, 2 , 3')
    assert_equal [3, 2], Additionals.split_ids('3, 2, 2')
    assert_equal [1, 2], Additionals.split_ids('1, 2 3')
    assert_empty Additionals.split_ids('')
    assert_equal [0], Additionals.split_ids('non-number')
  end

  def test_split_ids_with_ranges
    assert_equal [1, 2, 3, 4, 5], Additionals.split_ids('1, 2 , 3, 3 - 5')
    assert_equal [1, 2, 3, 4, 5], Additionals.split_ids('1, 2 , 3, 5 - 2')
    assert_equal [1, 2, 3], Additionals.split_ids('1, 2 , 3, 5 - 3 - 1')
  end

  def test_split_ids_with_restricted_large_range
    assert_equal [33_333, 33_334, 33_335, 33_336, 62_519], Additionals.split_ids('62519-33333', limit: 5)
  end

  def test_single_page_limit
    with_settings per_page_options: '10, 35, 50' do
      assert_equal 35, Additionals.single_page_limit
    end
  end

  def test_single_page_limit_with_single_setting
    with_settings per_page_options: '10' do
      assert_equal 10, Additionals.single_page_limit
    end
  end

  def test_single_page_limit_without_settings
    with_settings per_page_options: nil do
      assert_equal 25, Additionals.single_page_limit
    end
  end

  def test_name_sort_key_sorts_latin_names_without_case_and_accents
    names = %w[Zebra Öl äpfel Birne Émile ober]

    assert_equal(%w[äpfel Birne Émile ober Öl Zebra], names.sort_by { |name| Additionals.name_sort_key name })
  end

  # transliterate turns characters without a latin approximation into "?",
  # which made such names equal and left their order to chance
  def test_name_sort_key_sorts_names_without_latin_approximation_alphabetically
    names = %w[Яблоко Арбуз Привет]

    assert_equal(%w[Арбуз Привет Яблоко], names.sort_by { |name| Additionals.name_sort_key name })
  end

  def test_name_sort_key_puts_latin_names_before_other_scripts
    names = %w[東京 Привет Zebra äpfel]

    assert_equal(%w[äpfel Zebra Привет 東京], names.sort_by { |name| Additionals.name_sort_key name })
  end

  def test_name_sort_key_gives_the_same_order_for_any_input_order
    names = %w[東京 大阪 Привет Арбуз Zebra äpfel Äpfel]
    expected = names.sort_by { |name| Additionals.name_sort_key name }

    orders = Array.new(20) { |seed| names.shuffle random: Random.new(seed) }

    assert(orders.all? { |order| order.sort_by { |name| Additionals.name_sort_key name } == expected })
  end

  def test_name_sort_key_treats_decomposed_accents_like_composed_ones
    decomposed = "E\u0301mile"
    names = ['Emilia', decomposed]

    assert_equal([decomposed, 'Emilia'], names.sort_by { |name| Additionals.name_sort_key name })
  end

  def test_name_sort_key_accepts_nil_and_symbols
    assert_equal([nil, :a, 'b', :c], [:c, nil, 'b', :a].sort_by { |name| Additionals.name_sort_key name })
  end
end
