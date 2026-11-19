# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class GlobalFixturesHelperTest < Additionals::TestCase
  # Plugin fixtures are loaded outside of a test, and must not take the time
  # of the moment they happen to be loaded at
  def test_at_frozen_time_runs_at_the_time_of_the_tests
    travel_back
    travel_to 5.minutes.from_now

    loaded_at = Additionals::GlobalFixturesHelper.at_frozen_time { Time.now.to_i }

    assert_equal ActiveSupport::TestCase::FROZEN_TIME.to_i, loaded_at
  end
end
