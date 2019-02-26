require "test_helper"

class Hab::SDKTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Hab::SDK::VERSION
  end

  def test_it_does_something_useful
    assert false
  end
end
