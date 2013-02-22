require_relative 'test_common'
require_relative '../reachable'

class ReachableTest < MiniTest::Unit::TestCase
  def test_basic_rset
    r = Reachable.new
    r.constraints <+ [["1", BEGIN_ID, END_ID],
                      ["2", BEGIN_ID, END_ID],
                      ["3", BEGIN_ID, "1"],
                      ["4", "3", "1"]]
    r.tick

    expected = {
      "1" => [BEGIN_ID, END_ID].to_set,
      "2" => [BEGIN_ID, END_ID].to_set,
      "3" => [BEGIN_ID, END_ID, "1"].to_set,
      "4" => [BEGIN_ID, END_ID, "3", "1"].to_set,
      BEGIN_ID => [END_ID].to_set,
      END_ID => [BEGIN_ID].to_set
    }
    rv = r.reach_set.current_value.reveal
    rset = hash_map(rv) {|v| v.reveal}
    assert_equal(expected, rset)
  end

  # Like Enumerable#map, but map from Hash -> Hash rather than Hash -> Array.
  def hash_map(h)
    result = {}
    h.each_pair do |k,v|
      result[k] = yield v
    end
    result
  end
end
