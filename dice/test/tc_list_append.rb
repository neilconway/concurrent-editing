require_relative 'test_common'
require_relative 'ord_util'
require_relative '../list_append'

class ListAppendTest < MiniTest::Unit::TestCase
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
    s.input_buf <+ [["a", LIST_START_ID], ["b", "a"], ["c", "a"], ["d", "c"], ["f", "e"]]
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
    s.input_buf <+ [["a", LIST_START_ID], ["b", "a"], ["c", "b"]]
    s.tick

    check_linear_order(s, "a", "b", "c")
  end

  def test_simple_tiebreak
    s = ListAppend.new
    s.input_buf <+ [["a", LIST_START_ID], ["b", LIST_START_ID], ["c", LIST_START_ID]]
    s.tick

    check_linear_order(s, "a", "b", "c")
  end

  def test_use_ancestor_1
    s = ListAppend.new
    # We have Z -> X explicitly. Hypothetical tiebreaks are Y -> Z and X ->
    # Y. However, we should follow causal order when using tiebreaks, which
    # means we should first apply Y -> Z, which implies Y -> X; the latter order
    # should be preferred over the X -> Y tiebreak. Hence, the correct order
    # should be Y -> Z -> X.
    s.input_buf <+ [["z", LIST_START_ID], ["x", "z"], ["y", LIST_START_ID]]
    s.tick

    check_linear_order(s, "y", "z", "x")
  end

  def test_use_ancestor_2
    s = ListAppend.new
    # Two concurrent edits (m, n) which each have a child edit (b, a),
    # respectively; note that the tiebreak between b and n determines how b and
    # a should be ordered, not the tiebreak between b and a.
    s.input_buf <+ [["m", LIST_START_ID], ["n", LIST_START_ID],
                    ["b", "m"], ["a", "n"]]
    s.tick

    check_linear_order(s, "m", "b", "n", "a")
  end

  def test_use_ancestor_2_split
    s = ListAppend.new
    # Same as before, but divided into multiple ticks
    s.input_buf <+ [["m", LIST_START_ID], ["n", LIST_START_ID]]
    s.tick

    check_linear_order(s, "m", "n")

    s.input_buf <+ [["b", "m"], ["a", "n"]]
    s.tick

    check_linear_order(s, "m", "b", "n", "a")
  end

  def test_use_ancestor_3
    s = ListAppend.new
    s.input_buf <+ [["m", LIST_START_ID], ["n", LIST_START_ID],
                    ["b", "m"], ["a", "n"],
                    ["c", "b"], ["d", "a"]]
    s.tick

    print_linear_order(s)

    check_linear_order(s, "m", "b", "c", "n", "a", "d")
  end

  def test_use_ancestor_3_split
    s = ListAppend.new
    s.input_buf <+ [["m", LIST_START_ID], ["n", LIST_START_ID],
                    ["b", "m"], ["a", "n"]]
    s.tick

    check_linear_order(s, "m", "b", "n", "a")

    puts "********** TICK 1 FINISHED ***********"

    s.input_buf <+ [["c", "b"]]
    s.tick

    check_linear_order(s, "m", "b", "c", "n", "a")
  end

  def test_use_ancestor_4
    s = ListAppend.new
    s.input_buf <+ [["m", LIST_START_ID], ["n", LIST_START_ID],
                    ["b", "m"], ["a", "n"],
                    ["d", "b"], ["c", "a"]]
    s.tick

    check_linear_order(s, "m", "b", "d", "n", "a", "c")
  end

  def test_use_ancestor_5
    # Three children at the top-level
    s = ListAppend.new
    s.input_buf <+ [["m", LIST_START_ID], ["n", LIST_START_ID], ["o", LIST_START_ID],
                    ["c", "m"], ["b", "n"], ["a", "o"]]
    s.tick

    check_linear_order(s, "m", "c", "n", "b", "o", "a")
  end

  def test_two_concurrent_users1
    s = ListAppend.new
    s.input_buf <+ [["a1", LIST_START_ID],
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
    s.input_buf <+ [["c1", LIST_START_ID],
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
    s.input_buf <+ [["a1", LIST_START_ID],
                    ["b1", LIST_START_ID],
                    ["y", "a1"],
                    ["x", "b1"]]
    s.tick

    # Note that we interleave edits from different "users"
    check_linear_order(s, "a1", "b1", "x", "y")
  end

  def test_random_graph
    id_list = (0..30).map(&:to_s)
    id_list.shuffle!
    edit_list = []
    id_list.each_with_index do |elem,i|
      if i == 0
        pred = LIST_START_ID
      else
        pred = id_list[rand(i) % i]
      end
      edit_list << [elem, pred.to_s]
    end

    rv = []
    5.times do
      s = ListAppend.new
      s.input_buf <+ edit_list
      s.tick
      lp = LinearPrinter.new(s)
      assert_equal(id_list.length + 1, lp.strongly_connected_components.length)
      rv << lp.tsort
    end

    assert_equal(1, rv.uniq.length)
  end
end
