require 'rubygems'
require 'bud'

# Float::INFINITY only defined in MRI 1.9.2+
unless defined? Float::INFINITY
  Float::INFINITY = 1.0/0.0
end

BEGIN_NODE = -Float::INFINITY
END_NODE = Float::INFINITY

class SimpleTree
  include Bud

  state do
    table :root, [:node_id]
    table :edge, [:from, :to, :kind]

    # Insert operation state (transient)
    scratch :ins_init, [:op_id]
    scratch :ins_curr, [:op_id, :node_id, :depth]

    scratch :max_depth, [:op_id] => [:depth]
  end

  bootstrap do
    edge <= [[END_NODE, BEGIN_NODE, :left]]
    root <= [[END_NODE]]
  end

  bloom do
    ins_curr <= (ins_init * root).pairs {|i,r| [i.op_id, r.node_id, 0]}

    # If the to-be-inserted element is smaller than the current node, it must go
    # to the left. If it is larger, it must go to the right.
    # XXX: for now, we just assume that the nodes are ordered by ID
    ins_curr <= (ins_curr * edge).pairs(:node_id => :from) do |i,e|
      if e.kind == :left
        [i.op_id, e.to, i.depth + 1] if i.op_id < e.from
      elsif e.kind == :right
        [i.op_id, e.to, i.depth + 1] if i.op_id > e.from
      end
    end

    max_depth <= ins_curr.group([:op_id], max(:depth))
    edge <+ (max_depth * ins_curr).rights(:op_id => :op_id, :depth => :depth) do |i|
      [i.node_id, i.op_id, i.op_id < i.node_id ? :left : :right]
    end
  end
end
