require_relative 'test_common'
require_relative '../tree'

class SimpleTreeTest < MiniTest::Unit::TestCase
  def test_single_op
    t = SimpleTree.new
    t.ins_init <+ [[5]]
    t.tick
    t.tick
    assert_equal([BEGIN_NODE, 5, END_NODE], get_tree_seq(t))
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
