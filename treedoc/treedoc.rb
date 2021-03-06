require "rubygems"
require "bud"

class User
  attr_reader :root
  attr_writer :root
  attr_reader :dis

  def initialize(r, d)
    @root = r
    @dis = d
  end
end


class MiniNode
  include Enumerable

  attr_reader :left
  attr_reader :right
  attr_reader :dis
  attr_reader :atom
  attr_writer :atom

  def initialize(l, r, d, a)
    @left = l
    @right = r
    @dis = d
    @atom = a
  end

  def each(&blk)
    @left.each do |l|
      l.each(&blk)
    end
    blk.call(@atom)     # XXX: tombstones?
    @right.each do |r|
      r.each(&blk)
    end
  end

  def mini_merge(min)
    if self.left[0] != nil
       left_branch = self.left[0].merge_node(min.left[0])
    elsif ((self.left[0] == nil) and (min.left[0] == nil))
      left_branch = []
    else
      left_branch = min.left[0].copy_tree
    end

    if self.right[0] != nil
      right_branch = self.right[0].merge_node(min.right[0])
    elsif ((self.right[0] == nil) and (min.right[0] == nil))
      right_branch = []
    else
      right_branch = min.right[0].copy_tree
    end

    if self.atom.nil? or min.atom.nil?
      new_atom = nil
    else
      new_atom = self.atom
    end
    return MiniNode.new([left_branch], [right_branch], self.dis, new_atom)
  end
end

class TreeNode
  include Enumerable

  attr_accessor :minis

  def initialize(m)
    @minis = m
  end

  # Invokes the block for each atom in the tree, doing an in-order traversal
  # according to the treedoc semantics.
  def each(&blk)
    minis.each do |m|
      m.each(&blk)
    end
  end

  def copy_tree
    TreeNode.new(self.minis)
  end

  def find_index_of_mini(dis)
    self.minis.each do |mini|
      if mini.dis == dis
        return self.minis.index(mini)
      end
    end
  end

  def find_tree_node(path)
    if path.empty?
      return self
    end
    if path.first[0] == nil
      return self
    end
    current_step = path[0]
    dis = current_step[1]
    index = self.find_index_of_mini(dis)
    current_mini = self.minis[index]
    if current_step[0] == 0
      return current_mini.left[0].find_tree_node(path[1 .. path.length])
    elsif current_step[0] == 1
      return current_mini.right[0].find_tree_node(path[1 .. path.length])
    end
  end

  def check_empty_left
    if self.minis[0].left[0] == nil
      return true
    else
      return false
    end
  end

  def check_empty_right
    if self.minis[minis.length - 1].right[0] == nil
      return true
    else
      return false
    end
  end

  # Used when direct child of reference node is not nil.  Helps find spot in tree
  # directly before reference node.
  def find_farthest_right
    if self.minis[minis.length - 1].right[0] == nil
      return self
    else
      return self.minis[minis.length - 1].right[0].find_farthest_right
    end
  end

  # Helps find spot in tree directly after reference node when right child is not nil
  def find_farthest_left
    if self.minis[0].left[0] == nil
      return self
    else
      return self.minis[0].left[0].find_farthest_left
    end
  end

  def insert_before(path, atom, dis)
    new_mini = MiniNode.new([],[], dis, atom)
    new_node = TreeNode.new([new_mini])
    referenceNode = self.find_tree_node(path)

    if referenceNode.check_empty_left == true
      referenceNode.minis[0].left[0] = new_node
    else
      farthestRightNode = referenceNode.minis[0].left[0].find_farthest_right
      farthestRightNode.minis[minis.length - 1].right[0] = new_node
    end
  end

  def insert_after(path, atom, dis)
    new_mini = MiniNode.new([],[], dis, atom)
    new_node = TreeNode.new([new_mini])
    referenceNode = self.find_tree_node(path)
    if referenceNode.check_empty_right
      referenceNode.minis[minis.length - 1].right[0] = new_node
    else
      farthestLeftNode = referenceNode.minis[minis.length - 1].right[0].find_farthest_left
      farthestLeftNode.minis[0].left[0] = new_node
    end
  end

  def find_mini(path)
    my_tree_node = self.find_tree_node(path)
    temp = path[path.length - 1]
    disam = temp[1]
    index = my_tree_node.find_index_of_mini(disam)
    return my_tree_node.minis[index]
  end

  def delete(path)
    mini_to_delete = self.find_mini(path)
    mini_to_delete.atom = nil
  end

  def merge_node(tree)
    if tree.nil?
      return self.copy_tree
    end

    newMinis = []
    disams = []

    self.minis.each do |m|
      tree.minis.each do |n|
        if m.dis == n.dis
          newMinis << m.mini_merge(n)
          disams << m.dis
        end
      end
    end

    self.minis.each do |m|
      if not disams.include?(m.dis)
        newMinis << m
        disams << m.dis
      end
    end

    tree.minis.each do |m|
      if not disams.include?(m.dis)
        newMinis << m
        disams << m.dis
      end
    end

    return TreeNode.new(newMinis)
  end
end





class TreedocL < Bud::Lattice
  wrapper_name :tdoc

  def initialize
    @v = []
  end

  # XXX: monotone or morphism?
  monotone :insert_before do |pos,atom|
  end

  monotone :insert_after do |pos,atom|
  end

  # XXX: monotone or morphism?
  monotone :delete do |pos|
  end

  def contents
  end
end
