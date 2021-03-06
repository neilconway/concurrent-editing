require 'rubygems'
require 'bud'

# Float::INFINITY only defined in MRI 1.9.2+
unless defined? Float::INFINITY
  Float::INFINITY = 1.0/0.0
end

BEGIN_NODE = -Float::INFINITY
END_NODE = Float::INFINITY

# Goal: use something akin to SimpleTree (tree.rb) to implement a concurrent
# editing scheme.
#
# Differences:
#   (a) in SimpleTree, the order between atoms is given by a scalar comparison
#       of their IDs. In concurrent editing, the _explicit_ constraints are
#       given by the contents of a table.
#
#   (b) Additional details: the explicit constraints include both "pre" and
#       "post" nodes. Also, we want to consider the transitive consequences of
#       the explicit constraints, ideally without enumerating all of them.
#
#   (c) in SimpleTree, atom ID is a total order. In concurrent editing, the
#       explicit constraints only form a partial order. We'd then like to
#       resolve ambiguous situations by considering tiebreak and implied-by-anc
#       orders.
#
#   (d) another difference is that in SimpleTree, we start at the root when
#       trying to determine where a new insertion appears. In concurrent
#       editing, we have PRE and POST constraints; we know that the edit must
#       appear between these two nodes (according to the tree traversal order),
#       so we can immediately jump to either PRE or POST node and then walk
#       forward/backward from there.
#
# If we represent a partial order using SimpleTree, a node in the tree might
# have multiple left or right children. Naturally, we then want to assign an
# ordering to these children (i.e., find a monotone linearization of the input
# constraint set). One question is whether, given the explicit constraints and
# some sort of tiebreaking scheme, we should include the "tiebreaking" implied
# constraints in the tree, or whether those should be represented differently.
class TreeLinear
  include Bud

  state do
    table :root, [] => [:id]
    table :edge, [:from, :to, :kind]

    table :constr, [:id] => [:pre, :post]

    # Insert operation state (transient)
    scratch :ins_init, [:op_id]
    scratch :ins_state, [:op_id, :node_id]
  end

  bloom do
    # Start traversing the tree by beginning with the PRE constraint
    # XXX: probably worth denormalizing to store pre/post in the insert state
    ins_state <= (ins_init * constr).pairs(:op_id => :id) {|i,c| [i.op_id, c.pre]}

    # Given the current traversal position, decide whether we can place the new
    # edit here. We need to consider (a) the tiebreak between the new edit and
    # the current node (b) the new edit's POST constraint (we can't place an
    # edit after its POST constraint). All the nodes in the right subtree of a
    # node follow that node in the in-order traversal.
    ins_state <= (ins_state * edge).
  end
end
