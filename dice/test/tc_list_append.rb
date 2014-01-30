require_relative 'test_common'
require_relative '../list_append'

class ListAppendTest < MiniTest::Unit::TestCase
  def test_safe_tc
    s = ListAppend.new(:stratum_map => {
                         "explicit" => 0,
                         "safe" => 0,
                         "safe_tc" => 0,
                         "tiebreak" => 0,
                         "use_tiebreak" => 0,
                         "implied_anc" => 0,
                         "use_implied_anc" => 0,
                         "ord" => 0
                       })
    s.explicit <+ [["a", LIST_START_ID], ["b", "a"], ["c", "a"], ["d", "c"], ["f", "e"]]
    s.tick

    assert_equal([[LIST_START_ID, "a"], ["a", "b"], ["a", "c"],
                  ["c", "d"], LIST_START_TUPLE].to_set, s.safe.to_set)
    assert_equal([[LIST_START_ID, "a"], ["a", "b"], [LIST_START_ID, "b"],
                  ["a", "c"], [LIST_START_ID, "c"],
                  ["c", "d"], ["a", "d"], [LIST_START_ID, "d"],
                  LIST_START_TUPLE].to_set, s.safe_tc.to_set)
  end

  def test_use_ancestor_1
    s = ListAppend.new(:stratum_map => {
                         "explicit" => 0,
                         "safe" => 0,
                         "safe_tc" => 0,
                         "tiebreak" => 0,
                         "use_tiebreak" => 0,
                         "implied_anc" => 0,
                         "use_implied_anc" => 0,
                         "ord" => 0
                       })
    # We have Z -> X explicitly. Hypothetical tiebreaks are Y -> Z and X ->
    # Y. However, we should follow causal order when using tiebreaks, which
    # means we should first apply Y -> Z, which implies Y -> X; the latter order
    # should be preferred over the X -> Y tiebreak. Hence, resulting order
    # should be Y -> Z -> X.
    s.explicit <+ [["z", LIST_START_ID], ["x", "z"], ["y", LIST_START_ID]]
    s.tick

    puts s.tiebreak.to_a.sort.inspect
  end

  def test_key_conflict
  end
end
