require 'rubygems'
require 'minitest/autorun'
require './treedoc'

class TreeNodeTest < MiniTest::Unit::TestCase
  def test_basic_triangle
    left_mini = MiniNode.new([], [], nil, "a")
    left_node = TreeNode.new([left_mini])

    right_mini = MiniNode.new([], [], nil, "c")
    right_node = TreeNode.new([right_mini])

    root_mini = MiniNode.new([left_node], [right_node], nil, "b")
    root_node = TreeNode.new([root_mini])

    assert_equal(%w[a b c], root_node.to_a)
    assert_equal(%w[a c], root_node.select{|a| a != "b"})
    assert_equal(true, root_node.all?{|a| %w[a b c].include? a})
  end
end
