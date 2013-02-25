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
    check_invariants(r)
  end

  def test_bad_pre
    r = Reachable.new
    r.constraints <+ [["1", BEGIN_ID, END_ID],
                      ["2", BEGIN_ID, END_ID],
                      ["3", "4", END_ID]]
    r.tick
    assert_equal([["3", "4", END_ID]], r.bad_pre.to_a)
    check_invariants(r, :bad_pre)
  end

  def test_bad_post
    r = Reachable.new
    r.constraints <+ [["1", BEGIN_ID, END_ID],
                      ["2", BEGIN_ID, END_ID],
                      ["3", END_ID, "4"]]
    r.tick
    assert_equal([["3", END_ID, "4"]], r.bad_post.to_a)
    check_invariants(r, :bad_post)
  end

  def test_simple_cycle
  end

  def check_invariants(r, *skip)
    to_check = [:bad_pre, :bad_post, :cycle] - skip

    to_check.each do |t|
      assert_equal([], r.send(t).to_a, "expected '#{t}' to be empty")
    end
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
