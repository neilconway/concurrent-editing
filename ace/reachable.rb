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
    scratch :u_constraints, constraints.schema  # User constraints; omit sentinels

    # Alternative graph representation: [:from, :to] means that "from" must
    # precede "to".
    scratch :hasse, [:from, :to]
    scratch :hasse_tc, [:from, :to]

    scratch :reach_pre, [:from, :to]
    scratch :reach_post, [:from, :to]

    lmap :reach_set

    scratch :bad_pre, constraints.schema
    scratch :bad_post, constraints.schema
    scratch :cycle, [:id]

    # Output: a set of <a,b> pairs for all a,b \in constraints; [a,b] means that
    # a comes before b in the total order.
    scratch :orders, [:a, :b]
  end

  bootstrap do
    constraints <+ [[BEGIN_ID, nil, END_ID],
                    [END_ID, BEGIN_ID, nil]]
  end

  bloom :user_constraints do
    u_constraints <= constraints {|c| c unless [BEGIN_ID, END_ID].include? c.id}
  end

  bloom :reach_set do
    reach_pre <= constraints {|c| [c.id, c.id]}
    reach_pre <= (reach_pre * constraints).pairs(:to => :id) {|r,c| [r.from, c.pre] unless c.id == BEGIN_ID}

    reach_post <= constraints {|c| [c.id, c.id]}
    reach_post <= (reach_post * constraints).pairs(:to => :id) {|r,c| [r.from, c.post] unless c.id == END_ID}

    reach_set <= reach_pre {|r| {r.from => Bud::SetLattice.new([r.to])} unless r.from == r.to}
    reach_set <= reach_post {|r| {r.from => Bud::SetLattice.new([r.to])} unless r.from == r.to}
  end

  bloom :hasse do
    hasse <= constraints {|c| [c.pre, c.id] unless c.id == BEGIN_ID}
    hasse <= constraints {|c| [c.id, c.post] unless c.id == END_ID}

    hasse_tc <= hasse {|h| [h.from, h.to]}
    hasse_tc <= (hasse_tc * hasse).pairs(:to => :from) {|t,h| [t.from, h.to]}
  end

  bloom :integrity do
    # Check that constraints reference extant nodes, and that user constraints
    # don't claim to be before/after the start/end sentinels, respectively.
    bad_pre <= u_constraints.notin(constraints, :pre => :id)
    bad_post <= u_constraints.notin(constraints, :post => :id)

    # Check that constraint graph is acyclic
    cycle <= hasse_tc {|h| [h.from] if h.from == h.to}

    # NB: The previous constraints imply a few additional invariants:
    #
    #   (1) The graph is connected, since the only nodes not allowed to have
    #       valid pre/post constraints are the sentinels; hence, a subgraph that
    #       is not reachable from the main graph must contain a cycle.
    #
    #   (2) A constraint can't claim to appear before START_ID or after END_ID;
    #       such a constraint would imply a cycle.
    #
    #   (3) A constraint can't reference itself as its own pre/post pointer;
    #      such a constraint is a trivial cycle.
  end

  bloom :compute_orders do
    orders <= (constraints * constraints).pairs do |c1,c2|
      unless c1 == c2
        find_order(c1.id, c2.id, reach_set.at(c1.id), reach_set.at(c2.id))
      end
    end
    # HACK: make sure we push "orders" into a higher strata
    orders <= constraints.notin(constraints, :id => :id)
  end

  def find_order(a, b, a_rset, b_rset)
#    puts "find_order: a = #{a}, b = #{b}, a_rset = #{a_rset.inspect}, b_rset = #{b_rset}"
    a_rset = a_rset.reveal
    b_rset = b_rset.reveal
    if hasse_tc.has_key? [a,b]
      return [a,b]
    elsif hasse_tc.has_key? [b,a]
      return [b,a]
    else
      return [0, 0]
    end
  end

  def emit_viz(fname="constraint_graph")
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

    g.output(:pdf => "#{fname}.pdf")
  end

  def emit_hasse_viz(fname="hasse_graph")
    g = GraphViz.new(:G, :type => :digraph, :rankdir => "LR")
    hasse.each do |h|
      sg = case h.from
           when BEGIN_ID
             g.add_graph(h.from, :rank => "source")
           when END_ID
             g.add_graph(h.from, :rank => "sink")
           else
             g
           end

      sg.add_nodes(h.from)
      sg.add_edges(h.from, h.to)
    end

    g.output(:pdf => "#{fname}.pdf")
  end
end
