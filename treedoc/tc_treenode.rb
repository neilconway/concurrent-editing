require './test_common'
require 'rubygems'
require 'bud'
#require 'minitest/autorun'
require './treedoc'


class TreeNodeTest < Test::Unit::TestCase

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

  def test_find_basic_triangle
    left_mini = MiniNode.new([], [], nil, "a")
    left_node = TreeNode.new([left_mini])

    right_mini = MiniNode.new([], [], nil, "c")
    right_node = TreeNode.new([right_mini])
    
    root_mini = MiniNode.new([left_node], [right_node], nil, "b")
    root_node = TreeNode.new([root_mini])
    
    path = [1] 
    found_node = root_node.find_tree_node(path) 
    assert_equal(right_node, found_node)
  end

  def test_basic_insert_after
    left_mini = MiniNode.new([], [], nil, "a")
    left_node = TreeNode.new([left_mini])

    right_mini = MiniNode.new([], [], nil, "c")
    right_node = TreeNode.new([right_mini])
    
    root_mini = MiniNode.new([left_node], [right_node], nil, "b")
    root_node = TreeNode.new([root_mini])
    
    path = [1]
    referenceNode = root_node.find_tree_node(path)
    assert_equal(referenceNode, right_node)
    assert_equal(true, referenceNode.check_empty_right())

    root_node.insert_after(path, "d")

    assert_equal(["d"], right_node.minis[0].right[0].to_a)
  end

  def test_basic_insert_before
    left_mini = MiniNode.new([], [], nil, "a")
    left_node = TreeNode.new([left_mini])

    right_mini = MiniNode.new([], [], nil, "c")
    right_node = TreeNode.new([right_mini])
    
    root_mini = MiniNode.new([left_node], [right_node], nil, "b")
    root_node = TreeNode.new([root_mini])
    
    path = [0]
    referenceNode = root_node.find_tree_node(path)
    assert_equal(referenceNode, left_node)
    assert_equal(true, referenceNode.check_empty_left())
    
    root_node.insert_before(path, "d")
    assert_equal(["d"], left_node.minis[0].left[0].to_a)
  end

  def test_find_farthest_right
    leaf_mini= MiniNode.new([],[], nil, "d")
    leaf_node = TreeNode.new([leaf_mini])

    left_mini = MiniNode.new([], [leaf_node], nil, "a")
    left_node = TreeNode.new([left_mini])

    right_mini = MiniNode.new([], [], nil, "c")
    right_node = TreeNode.new([right_mini])
    
    root_mini = MiniNode.new([left_node], [right_node], nil, "b")
    root_node = TreeNode.new([root_mini])

    assert_equal(leaf_node, left_node.find_farthest_right())
  end

  def test_find_farthest_left
    leaf_mini= MiniNode.new([],[], nil, "d")
    leaf_node = TreeNode.new([leaf_mini])

    left_mini = MiniNode.new([], [], nil, "a")
    left_node = TreeNode.new([left_mini])

    right_mini = MiniNode.new([leaf_node], [], nil, "c")
    right_node = TreeNode.new([right_mini])
    
    root_mini = MiniNode.new([left_node], [right_node], nil, "b")
    root_node = TreeNode.new([root_mini])

    assert_equal(leaf_node, right_node.find_farthest_left())
  end


  def test_medium_insert_before
    left_mini = MiniNode.new([], [], nil, "a")
    left_node = TreeNode.new([left_mini])

    right_mini = MiniNode.new([], [], nil, "c")
    right_node = TreeNode.new([right_mini])
    
    root_mini = MiniNode.new([left_node], [right_node], nil, "b")
    root_node = TreeNode.new([root_mini])

    path = []
    referenceNode = root_node.find_tree_node(path)
    assert_equal(referenceNode, root_node)
    assert_equal(false, referenceNode.check_empty_left())
    farthest_right_node = referenceNode.minis[0].left[0].find_farthest_right()
    assert_equal(left_node, farthest_right_node)
    
    root_node.insert_before(path, "d")
    assert_equal(["d"], left_node.minis[0].right[0].to_a)
  end


  # XXX: This test doesn't pass- need to fix!!  But in insert_after
  def test_medium_insert_after
    left_mini = MiniNode.new([], [], nil, "a")
    left_node = TreeNode.new([left_mini])

    right_mini = MiniNode.new([], [], nil, "c")
    right_node = TreeNode.new([right_mini])
    
    root_mini = MiniNode.new([left_node], [right_node], nil, "b")
    root_node = TreeNode.new([root_mini])

    path = []
    referenceNode = root_node.find_tree_node(path)
    assert_equal(referenceNode, root_node)

    assert_equal(false, referenceNode.check_empty_right())
    farthest_left_node = referenceNode.minis[0].right[0].find_farthest_left()
    assert_equal(right_node, farthest_left_node)
    
    root_node.insert_after(path, "d")
    assert_equal(["d"], right_node.minis[0].left[0].to_a)    
  end
    
    
end

