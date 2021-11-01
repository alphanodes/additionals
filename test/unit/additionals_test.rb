# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class AdditionalsTest < Additionals::TestCase
  fixtures :projects, :users, :members, :member_roles, :roles,
           :trackers, :projects_trackers,
           :enabled_modules,
           :enumerations

  include Redmine::I18n

  def setup
    prepare_tests
  end

  def test_true
    assert Additionals.true? 1
    assert Additionals.true? true
    assert Additionals.true? 'true'
    assert Additionals.true? 'True'

    assert_not Additionals.true?(-1)
    assert_not Additionals.true? 0
    assert_not Additionals.true? '0'
    assert_not Additionals.true? 1000
    assert_not Additionals.true? false
    assert_not Additionals.true? 'false'
    assert_not Additionals.true? 'False'
    assert_not Additionals.true? 'yes'
    assert_not Additionals.true? ''
    assert_not Additionals.true? nil
    assert_not Additionals.true? 'unknown'
  end

  def test_false
    assert Additionals.false? false
    assert Additionals.false? nil
    assert Additionals.false? 'false'
    assert Additionals.false? 0

    assert_not Additionals.false? 1
    assert_not Additionals.false? 'true'
    assert_not Additionals.false? 'True'
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

  def test_load_macros
    macros = Additionals.load_macros

    assert macros.count.positive?
    assert(macros.detect { |macro| macro.include? 'fa_macro' })
  end

  def test_split_ids
    assert_equal [1, 2, 3], Additionals.split_ids('1, 2 , 3')
    assert_equal [3, 2], Additionals.split_ids('3, 2, 2')
    assert_equal [1, 2], Additionals.split_ids('1, 2 3')
    assert_equal [], Additionals.split_ids('')
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
end
