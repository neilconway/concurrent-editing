require 'rubygems'
require 'bud'
require 'graphviz'

BEGIN_ID = "__begin__"
END_ID = "__end__"

class Reachable
  include Bud

  state do
    # The constraint that the given ID must follow the "pre" node and precede
    # the "post" node.
    table :constraints, [:id] => [:pre, :post]

    scratch :reach_pre, [:from, :to]
    scratch :reach_post, [:from, :to]

    lmap :reach_set

    scratch :bad_pre, constraints.schema
    scratch :bad_post, constraints.schema
  end

  bootstrap do
    constraints <+ [[BEGIN_ID, nil, END_ID],
                    [END_ID, BEGIN_ID, nil]]
  end

  bloom do
    reach_pre <= constraints {|c| [c.id, c.id]}
    reach_pre <= (reach_pre * constraints).pairs(:to => :id) {|r,c| [r.from, c.pre] unless c.pre.nil?}

    reach_post <= constraints {|c| [c.id, c.id]}
    reach_post <= (reach_post * constraints).pairs(:to => :id) {|r,c| [r.from, c.post] unless c.post.nil?}

    reach_set <= reach_pre {|r| {r.from => Bud::SetLattice.new([r.to])} unless r.from == r.to}
    reach_set <= reach_post {|r| {r.from => Bud::SetLattice.new([r.to])} unless r.from == r.to}
  end

  bloom :integrity do
    # Check that constraints reference extant nodes
    bad_pre <= constraints.notin(constraints, :pre => :id)
    bad_post <= constraints.notin(constraints, :post => :id)

    # Check that constraint graph is acyclic

    # Check that constraint graph is connected
  end

  def emit_viz
    g = GraphViz.new(:G, :type => :digraph, :rankdir => "LR")
    constraints.each do |c|
      sg = case c.id
           when BEGIN_ID
             g.add_graph(c.id, :rank => "source")
           when END_ID
             g.add_graph(c.id, :rank => "sink")
           else
             g
           end

      sg.add_nodes(c.id)
      g.add_edges(c.id, c.pre, :label => "Pre") if c.pre
      g.add_edges(c.id, c.post, :label => "Post") if c.post
    end

    g.output(:pdf => "reachable.pdf")
  end
end
