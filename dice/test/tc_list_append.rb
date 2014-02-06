require_relative 'test_common'
require_relative '../list_append'

require 'tsort'

class LinearPrinter
  include TSort

  def initialize(b)
    @bud = b
  end

  def tsort_each_node(&blk)
    @bud.ord.to_a.map {|t| t.id}.uniq.each(&blk)
  end

  def tsort_each_child(node, &blk)
    @bud.ord.to_a.each do |t|
      if t.id == node
        blk.call(t.pred) unless t.pred.nil?
      end
    end
  end
end

class ListAppendTest < MiniTest::Unit::TestCase
  def print_linear_order(b)
    puts LinearPrinter.new(b).tsort.inspect
  end

  def check_linear_order(b, *vals)
    vals = [LIST_START_ID] + vals
    ary = []
    vals.each_with_index do |v,i|
      i.times do |j|
        ary << [vals[i], vals[j]]
      end
    end
    ary << LIST_START_TUPLE
    assert_equal(ary.sort, b.ord.to_a.sort)
  end

  def test_safe_tc
    s = ListAppend.new
    s.explicit <+ [["a", LIST_START_ID], ["b", "a"], ["c", "a"], ["d", "c"], ["f", "e"]]
    s.tick

    assert_equal([["a", LIST_START_ID], ["b", "a"], ["c", "a"], ["d", "c"],
                  LIST_START_TUPLE].to_set, s.safe.to_set)
    assert_equal([["a", LIST_START_ID], ["b", LIST_START_ID],
                  ["c", LIST_START_ID], ["d", LIST_START_ID],
                  ["b", "a"], ["c", "a"], ["d", "c"], ["d", "a"],
                  LIST_START_TUPLE].to_set, s.safe_tc.to_set)
  end

  def test_linear_chain
    s = ListAppend.new
    s.explicit <+ [["a", LIST_START_ID], ["b", "a"], ["c", "b"]]
    s.tick

    check_linear_order(s, "a", "b", "c")
  end

  def test_simple_tiebreak
    s = ListAppend.new
    s.explicit <+ [["a", LIST_START_ID], ["b", LIST_START_ID], ["c", LIST_START_ID]]
    s.tick

    check_linear_order(s, "a", "b", "c")
  end

  def test_use_ancestor_1
    s = ListAppend.new
    # We have Z -> X explicitly. Hypothetical tiebreaks are Y -> Z and X ->
    # Y. However, we should follow causal order when using tiebreaks, which
    # means we should first apply Y -> Z, which implies Y -> X; the latter order
    # should be preferred over the X -> Y tiebreak. Hence, resulting order
    # should be Y -> Z -> X.
    s.explicit <+ [["z", LIST_START_ID], ["x", "z"], ["y", LIST_START_ID]]
    s.tick

    check_linear_order(s, "y", "z", "x")
  end

  def test_two_concurrent_users1
    s = ListAppend.new
    s.explicit <+ [["a1", LIST_START_ID],
                   ["a2", "a1"],
                   ["a3", "a2"],
                   ["a4", "a3"],
                   ["b1", LIST_START_ID],
                   ["b2", "b1"],
                   ["b3", "b2"],
                   ["b4", "b3"]]
    s.tick

    check_linear_order(s, "a1", "a2", "a3", "a4", "b1", "b2", "b3", "b4")
  end

  def test_two_concurrent_users2
    s = ListAppend.new
    s.explicit <+ [["c1", LIST_START_ID],
                   ["c2", "c1"],
                   ["c3", "c2"],
                   ["c4", "c3"],
                   ["b1", LIST_START_ID],
                   ["b2", "b1"],
                   ["b3", "b2"],
                   ["b4", "b3"]]
    s.tick

    check_linear_order(s, "b1", "b2", "b3", "b4", "c1", "c2", "c3", "c4")
  end

  def test_two_concurrent_users3
    s = ListAppend.new
    s.explicit <+ [["a1", LIST_START_ID],
                   ["b1", LIST_START_ID],
                   ["y", "a1"],
                   ["x", "b1"]]
    s.tick

    # Note that we interleave edits from different "users"
    check_linear_order(s, "a1", "b1", "x", "y")
  end
end
