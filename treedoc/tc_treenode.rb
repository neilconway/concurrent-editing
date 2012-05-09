require './test_common'
require 'rubygems'
require 'bud'
require './treedoc'


class TreeNodeTest < MiniTest::Unit::TestCase
  def test_basic_triangle
    left_mini = MiniNode.new([], [], 0, "a")
    left_node = TreeNode.new([left_mini])

    right_mini = MiniNode.new([], [], 0, "c")
    right_node = TreeNode.new([right_mini])

    root_mini = MiniNode.new([left_node], [right_node], 0, "b")
    root_node = TreeNode.new([root_mini])

    assert_equal(%w[a b c], root_node.to_a)
    assert_equal(%w[a c], root_node.select{|x| x != "b"})
    assert_equal(true, root_node.all?{|x| %w[a b c].include? x})
  end

  def test_find_index_of_mini
    mini_1 = MiniNode.new([], [], 90, "a")
    mini_2 = MiniNode.new([], [], 100, "b")
    mini_3 = MiniNode.new([], [], 110, "c")
    root = TreeNode.new([mini_1, mini_2, mini_3])
    assert_equal(1, root.find_index_of_mini(100))
  end

  def test_find_basic_triangle
    left_mini = MiniNode.new([], [], 0, "a")
    left_node = TreeNode.new([left_mini])

    right_mini = MiniNode.new([], [], 0, "c")
    right_node = TreeNode.new([right_mini])

    root_mini = MiniNode.new([left_node], [right_node], 0, "b")
    root_node = TreeNode.new([root_mini])

    path = [[1,0]]
    found_node = root_node.find_tree_node(path)
    assert_equal(right_node, found_node)
  end

  def test_find_long_path_with_disambiguators
    farthest_left_mini = MiniNode.new([], [], 0, "e")
    farthest_left_node = TreeNode.new([farthest_left_mini])

    far_left_mini = MiniNode.new([farthest_left_node], [], 0, "d")
    far_left_node = TreeNode.new([far_left_mini])

    left_mini = MiniNode.new([far_left_node], [], 0, "a")
    left_node = TreeNode.new([left_mini])

    right_mini = MiniNode.new([], [], 0, "c")
    right_node = TreeNode.new([right_mini])

    root_mini = MiniNode.new([left_node], [right_node], 0, "b")
    root_node = TreeNode.new([root_mini])

    path = [[0, 0], [0, 0], [0, 0], [nil, 0]]
    found_node = root_node.find_tree_node(path)
    assert_equal(found_node, farthest_left_node)
  end

  def test_basic_insert_after
    left_mini = MiniNode.new([], [], 0, "a")
    left_node = TreeNode.new([left_mini])

    right_mini = MiniNode.new([], [], 0, "c")
    right_node = TreeNode.new([right_mini])

    root_mini = MiniNode.new([left_node], [right_node], 0, "b")
    root_node = TreeNode.new([root_mini])

    path = [[1,0]]
    referenceNode = root_node.find_tree_node(path)
    assert_equal(referenceNode, right_node)
    assert_equal(true, referenceNode.check_empty_right())
    path = [[1,0]]
    root_node.insert_after(path, "d", 0)

    assert_equal(["d"], right_node.minis[0].right[0].to_a)
  end

  def test_basic_insert_before
    left_mini = MiniNode.new([], [], 0, "a")
    left_node = TreeNode.new([left_mini])

    right_mini = MiniNode.new([], [], 0, "c")
    right_node = TreeNode.new([right_mini])

    root_mini = MiniNode.new([left_node], [right_node], 0, "b")
    root_node = TreeNode.new([root_mini])

    path = [[0,0]]
    referenceNode = root_node.find_tree_node(path)
    assert_equal(referenceNode, left_node)
    assert_equal(referenceNode.minis[0].left[0], nil)
    assert_equal(true, referenceNode.check_empty_left())

    path = [[0,0]]
    root_node.insert_before(path, "d", 0)
    assert_equal(%w[d a b c], root_node.to_a)
    assert_equal(["d"], left_node.minis[0].left[0].to_a)
  end

  def test_find_farthest_right
    leaf_mini= MiniNode.new([],[], 0, "d")
    leaf_node = TreeNode.new([leaf_mini])

    left_mini = MiniNode.new([], [leaf_node], 0, "a")
    left_node = TreeNode.new([left_mini])

    right_mini = MiniNode.new([], [], 0, "c")
    right_node = TreeNode.new([right_mini])

    root_mini = MiniNode.new([left_node], [right_node], 0, "b")
    root_node = TreeNode.new([root_mini])

    assert_equal(leaf_node, left_node.find_farthest_right())
  end

  def test_find_farthest_left
    leaf_mini= MiniNode.new([],[], 0, "d")
    leaf_node = TreeNode.new([leaf_mini])

    left_mini = MiniNode.new([], [], 0, "a")
    left_node = TreeNode.new([left_mini])

    right_mini = MiniNode.new([leaf_node], [], 0, "c")
    right_node = TreeNode.new([right_mini])

    root_mini = MiniNode.new([left_node], [right_node], 0, "b")
    root_node = TreeNode.new([root_mini])

    assert_equal(leaf_node, right_node.find_farthest_left())
  end


  def test_medium_insert_before
    left_mini = MiniNode.new([], [], 0, "a")
    left_node = TreeNode.new([left_mini])

    right_mini = MiniNode.new([], [], 0, "c")
    right_node = TreeNode.new([right_mini])

    root_mini = MiniNode.new([left_node], [right_node], 0, "b")
    root_node = TreeNode.new([root_mini])

    path = [[nil, 0]]
    referenceNode = root_node.find_tree_node(path)
    assert_equal(referenceNode, root_node)
    assert_equal(false, referenceNode.check_empty_left())
    farthest_right_node = referenceNode.minis[0].left[0].find_farthest_right()
    assert_equal(left_node, farthest_right_node)
    path = [[nil, 0]]
    root_node.insert_before(path, "d", 0)
    assert_equal(["d"], left_node.minis[0].right[0].to_a)
  end


  def test_medium_insert_after
    left_mini = MiniNode.new([], [], 0, "a")
    left_node = TreeNode.new([left_mini])

    right_mini = MiniNode.new([], [], 0, "c")
    right_node = TreeNode.new([right_mini])

    root_mini = MiniNode.new([left_node], [right_node], 0, "b")
    root_node = TreeNode.new([root_mini])

    path = [[nil, 0]]
    referenceNode = root_node.find_tree_node(path)
    assert_equal(referenceNode, root_node)

    assert_equal(false, referenceNode.check_empty_right())
    farthest_left_node = referenceNode.minis[0].right[0].find_farthest_left()
    assert_equal(right_node, farthest_left_node)

    root_node.insert_after(path, "d", 0)
    assert_equal(["d"], right_node.minis[0].left[0].to_a)
  end

  def test_hard_insert_before
    far_left_mini = MiniNode.new([], [], 0, "d")
    far_left_node = TreeNode.new([far_left_mini])

    left_mini = MiniNode.new([far_left_node], [], 0, "a")
    left_node = TreeNode.new([left_mini])

    right_mini = MiniNode.new([], [], 0, "c")
    right_node = TreeNode.new([right_mini])

    root_mini = MiniNode.new([left_node], [right_node], 0, "b")
    root_node = TreeNode.new([root_mini])

    path = [[0,0]]
    root_node.insert_before(path, "e", 0)
    assert_equal(["e"], far_left_node.minis[0].right[0].to_a)
  end

  def test_crazy_hard_insert_before
    far_left_mini = MiniNode.new([], [], 0, "d")
    far_left_node = TreeNode.new([far_left_mini])

    left_mini = MiniNode.new([far_left_node], [], 0, "a")
    left_node = TreeNode.new([left_mini])

    right_mini = MiniNode.new([], [], 0, "c")
    right_node = TreeNode.new([right_mini])

    root_mini = MiniNode.new([left_node], [right_node], 0, "b")
    root_node = TreeNode.new([root_mini])

    path = [[0,0]]
    root_node.insert_before(path, "e", 0)
    path = [[0,0]]
    root_node.insert_before(path, "f", 0)

    assert_equal(["f"], far_left_node.minis[0].right[0].minis[0].right[0].to_a)
  end

  def test_find_mini
    left_mini = MiniNode.new([], [], 0, "a")
    left_node = TreeNode.new([left_mini])

    right_mini = MiniNode.new([], [], 0, "c")
    right_node = TreeNode.new([right_mini])

    root_mini = MiniNode.new([left_node], [right_node], 0, "b")
    root_node = TreeNode.new([root_mini])
    path = [[0, 0], [nil, 0]]

    found_mini = root_node.find_mini(path)
    assert_equal(found_mini, left_mini)
  end

  def test_simple_delete
    left_mini = MiniNode.new([], [], 0, "a")
    left_node = TreeNode.new([left_mini])

    right_mini = MiniNode.new([], [], 0, "c")
    right_node = TreeNode.new([right_mini])

    root_mini = MiniNode.new([left_node], [right_node], 0, "b")
    root_node = TreeNode.new([root_mini])
    path = [[0, 0], [nil, 0]]

    root_node.delete(path)
    assert_equal([nil, "b", "c"], root_node.to_a)
  end

  def test_medium_delete
    far_right_mini = MiniNode.new([], [], 0, "e")
    far_right_node = TreeNode.new([far_right_mini])

    far_left_mini = MiniNode.new([], [], 0, "d")
    far_left_node = TreeNode.new([far_left_mini])

    left_mini = MiniNode.new([far_left_node], [], 0, "a")
    left_node = TreeNode.new([left_mini])

    right_mini = MiniNode.new([], [far_right_node], 0, "c")
    right_node = TreeNode.new([right_mini])

    root_mini = MiniNode.new([left_node], [right_node], 0, "b")
    root_node = TreeNode.new([root_mini])

    path1 = [[0,0], [0,0], [nil, 0]]
    path2 = [[1,0], [1,0], [nil, 0]]
    path3 = [[nil,0]]

    root_node.delete(path1)
    assert_equal([nil, "a", "b", "c", "e"], root_node.to_a)

    root_node.delete(path2)
    assert_equal([nil, "a", "b", "c", nil], root_node.to_a)

    root_node.delete(path3)
    assert_equal([nil, "a", nil, "c", nil], root_node.to_a)
  end

  def test_merge_node
    left_mini = MiniNode.new([], [], 0, "a")
    left_node = TreeNode.new([left_mini])

    right_mini = MiniNode.new([], [], 0, "c")
    right_node = TreeNode.new([right_mini])

    root_mini = MiniNode.new([left_node], [right_node], 0, "b")
    root_node = TreeNode.new([root_mini])

    root_mini2 = MiniNode.new([], [], 1, "e")
    root_node2 = TreeNode.new([root_mini2])


    assert_equal(1, root_node.minis.length)
    newTree = root_node.merge_node(root_node2)
    assert_equal(2, newTree.minis.length)

    assert_equal(%w[a b c e], newTree.to_a)
  end

  def test_merge_node_with_multiple_minis
    left_mini = MiniNode.new([], [], 0, "a")
    left_node = TreeNode.new([left_mini])

    right_mini = MiniNode.new([], [], 0, "c")
    right_node = TreeNode.new([right_mini])

    root_mini = MiniNode.new([left_node], [right_node], 0, "b")
    root_node = TreeNode.new([root_mini])

    root_mini2 = MiniNode.new([], [], 1, "e")
    root_node2 = TreeNode.new([root_mini, root_mini2])


    assert_equal(1, root_node.minis.length)
    new_tree = root_node.merge_node(root_node2)
    assert_equal(2, new_tree.minis.length)


    assert_equal(%w[a b c e], new_tree.to_a)
  end

  def test_merge_node_with_nil
    extra_mini = MiniNode.new([], [], 0, nil)
    extra_node = TreeNode.new([extra_mini])

    root_mini = MiniNode.new([], [], 0, "b")
    root_node = TreeNode.new([root_mini])

    newTree = root_node.merge_node(extra_node)
    assert_equal([nil], newTree.to_a)
  end

  def test_sanity_check
    left_mini = MiniNode.new([], [], 0, "a")
    left_node = TreeNode.new([left_mini])

    right_mini = MiniNode.new([], [], 0, "c")
    right_node = TreeNode.new([right_mini])

    extra_mini = MiniNode.new([], [], 1, "d")

    root_mini = MiniNode.new([left_node], [right_node], 0, "b")
    root_node = TreeNode.new([root_mini, extra_mini])

    assert_equal(%w[a b c d], root_node.to_a)
  end


  def test_2_users_simple
    user1_mini1 = MiniNode.new([], [], 1, "hi")
    user1_node1 = TreeNode.new([user1_mini1])

    user2_mini1 = MiniNode.new([], [], 1, "hi")
    user2_node1 = TreeNode.new([user2_mini1])

    emily = User.new(user1_node1, 5)
    neil = User.new(user2_node1, 7)

    emily.root.insert_after([[nil,1]], "Emily", emily.dis)

    assert_equal(["hi", "Emily"], emily.root.to_a)
    assert_equal(["hi"], neil.root.to_a)
    assert_equal(5, emily.root.minis[0].right[0].minis[0].dis)

    neil.root.insert_after([[nil,1]], "Neil", neil.dis)
    assert_equal(["hi", "Neil"], neil.root.to_a)

    newTree = emily.root.merge_node(neil.root)
    assert_equal(["hi", "Emily", "Neil"], newTree.to_a)
    assert_equal("hi", newTree.minis[0].atom.to_s)
    assert_equal("Emily", newTree.minis[0].right[0].minis[0].atom.to_s)
    assert_equal("Neil", newTree.minis[0].right[0].minis[1].atom.to_s)

  end

  def test_2_users_concurrent_delete
    left_mini = MiniNode.new([], [], 0, "a")
    left_node = TreeNode.new([left_mini])

    right_mini = MiniNode.new([], [], 0, "c")
    right_node = TreeNode.new([right_mini])

    root_mini = MiniNode.new([left_node], [right_node], 0, "b")
    root_node = TreeNode.new([root_mini])

    bob = User.new(root_node, 2)

    left_mini2 = MiniNode.new([], [], 0, "a")
    left_node2 = TreeNode.new([left_mini2])

    right_mini2 = MiniNode.new([], [], 0, "c")
    right_node2 = TreeNode.new([right_mini2])

    root_mini2 = MiniNode.new([left_node2], [right_node2], 0, "b")
    root_node2 = TreeNode.new([root_mini2])

    billy = User.new(root_node2, 3)

    bob.root.delete([[0,0],[nil,0]])
    assert_equal([nil, "b", "c"], bob.root.to_a)

    billy.root.delete([[1,0],[nil,0]])
    assert_equal(["a", "b", nil], billy.root.to_a)

    newTree = bob.root.merge_node(billy.root)
    assert_equal([nil, "b", nil], newTree.to_a)
  end
end
