require 'rubygems'
require 'bud'

# Simple implementation of topological sort in Bloom. Cribbed from
# http://lmeyerov.blogspot.com/2011/04/topological-sort-in-datalog.html
class TSort
  include Bud

  state do
    table :edge, [:from, :to]
    scratch :node, [:n]
    scratch :path, [:from, :to]
    scratch :min_cost, [:n] => [:c]
  end

  bloom do
    path <= edge
    path <= (path * edge).pairs(:to => :from) {|p,e| [p.from, e.to]}

    node <= edge {|e| [e.from]}
    node <= edge {|e| [e.to]}

    min_cost <= node {|n| [n.n, Bud::MaxLattice.new(0)]}
    min_cost <= (min_cost * path).pairs(:n => :from) {|m,p| [p.to, m.c + 1]}
  end
end

