require_relative 'test_common'
require_relative '../tree'

class SimpleTreeTest < MiniTest::Unit::TestCase
  def test_single_op
    t = SimpleTree.new
    t.ins_init <+ [[5]]
    t.tick
    t.tick
    check_invariants(t)
    assert_equal([BEGIN_NODE, 5, END_NODE], get_tree_seq(t))
  end

  # XXX: we can't safely insert two operations into the tree during the same
  # tick.
  def test_two_ops
    t = SimpleTree.new
    t.ins_init <+ [[7]]
    t.tick
    t.ins_init <+ [[8]]
    t.tick
    t.tick
    check_invariants(t)
    assert_equal([BEGIN_NODE, 7, 8, END_NODE], get_tree_seq(t))
  end

  def test_random_ops
    ops = Array.new(200) { rand(100000) }
    ops.uniq!
    t = SimpleTree.new
    ops.each {|o| t.ins_init <+ [[o]]; t.tick }
    t.tick

    sorted_ops = ops.sort
    check_invariants(t)
    assert_equal([BEGIN_NODE, *sorted_ops, END_NODE], get_tree_seq(t))
  end

  def check_invariants(t)
    t.edge.each do |e|
      assert_equal(e.from > e.to, e.kind == :left, "e = #{e}")
    end
  end

  def visit_node(n, t, &blk)
    return if n.nil?
    visit_node(get_child(n, t, :left), t, &blk)
    blk.call(n)
    visit_node(get_child(n, t, :right), t, &blk)
  end

  def get_child(n, t, kind)
    edges = t.edge.select {|e| e.from == n && e.kind == kind}
    case edges.length
    when 0
        return nil
    when 1
        return edges.first.to
    else
        raise
    end
  end

  def get_tree_seq(t)
    result = []
    root = t.root.to_a.first.node_id
    visit_node(root, t) do |n|
      result << n
    end

    return result
  end
end
