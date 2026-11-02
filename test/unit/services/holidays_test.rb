# frozen_string_literal: true

require File.expand_path '../../../test_helper', __FILE__

class HolidaysTest < Additionals::TestCase
  def setup
    # A plugin managing holidays answers on its own, see Additionals::Holidays
    skip 'holidays are managed by a plugin' if Additionals::Holidays.method(:dates).owner != Additionals::Holidays.singleton_class
  end

  # Redmine 7.0 has no non-working dates
  # TODO(Redmine 7.0 EOL): remove
  def test_there_are_no_holidays_without_non_working_dates
    skip 'Redmine 7.0 only' if defined?(::NonWorkingDate)

    assert_empty Additionals::Holidays.dates
    assert_empty Additionals::Holidays.dates_for(users(:users_002), Date.new(2030, 1, 1)..Date.new(2030, 12, 31))
    assert_not Additionals::Holidays.holiday?(Date.new(2030, 12, 25))
  end

  def test_dates_are_the_non_working_dates_of_redmine
    skip 'Redmine 7.1 only' unless defined?(::NonWorkingDate)

    NonWorkingDate.create! date: Date.new(2030, 5, 1), name: 'Labour Day'
    NonWorkingDate.create! date: Date.new(2030, 12, 25), name: 'Christmas'

    assert_equal [Date.new(2030, 5, 1)], Additionals::Holidays.dates(Date.new(2030, 1, 1)..Date.new(2030, 6, 30))
    assert_equal [Date.new(2030, 5, 1), Date.new(2030, 12, 25)], Additionals::Holidays.dates
    assert_equal Additionals::Holidays.dates, Additionals::Holidays.dates_for(users(:users_002))
    assert Additionals::Holidays.holiday?(Date.new(2030, 12, 25))
    assert_not Additionals::Holidays.holiday?(Date.new(2030, 12, 24))
  end
end
