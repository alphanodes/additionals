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
end
