# frozen_string_literal: true

require_relative "test_helper"

class TestMapOfConsciousness < Minitest::Test
  def test_calibrations
    assert_equal 20, MapOfConsciousness.calibrate(:shame)
    assert_equal 100, MapOfConsciousness.calibrate(:fear)
    assert_equal 200, MapOfConsciousness.calibrate(:courage)
    assert_equal 500, MapOfConsciousness.calibrate(:love)
    assert_equal 700, MapOfConsciousness.calibrate(:enlightenment)
  end

  def test_courage_is_the_threshold
    assert_equal 200, MapOfConsciousness::COURAGE
    assert MapOfConsciousness.below_courage?(175)
    refute MapOfConsciousness.below_courage?(200)
  end

  def test_the_map_is_frozen
    assert MapOfConsciousness::LEVELS.frozen?
  end

  def test_unknown_level_raises
    assert_raises(KeyError) { MapOfConsciousness.calibrate(:ennui) }
  end

  def test_name_of_reads_a_calibration_back_onto_the_map
    assert_equal :desire, MapOfConsciousness.name_of(125)
    assert_equal :fear, MapOfConsciousness.name_of(110)
    assert_equal :love, MapOfConsciousness.name_of(510)
  end
end
