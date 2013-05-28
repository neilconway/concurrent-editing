require 'rubygems'
require 'bud'

# Float::INFINITY only defined in MRI 1.9.2+
unless defined? Float::INFINITY
  Float::INFINITY = 1.0/0.0
end

BEGIN_NODE = -Float::INFINITY
END_NODE = Float::INFINITY

# Goal: use the tree-like stuff described in tree.rb to implement a concurrent
# editing scheme.
#
# Differences:
#   (a) in tree.rb, the order between atoms is given by a scalar comparison of
#       their IDs. In concurrent editing, the _explicit_ constraints are given
#       by the contents of a table.
#   (b) in tree.rb, atom ID is a total order. In concurrent editing, the
#       explicit constraints only form a partial order. We'd then like to
#       resolve ambiguous situations by considering tiebreak and implied-by-anc
#       orders.
