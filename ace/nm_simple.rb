require 'rubygems'
require 'bud'

BEGIN_ID = "__begin__"
END_ID = "__end__"

# TODO: add-back integrity constraints
class SimpleNmLinear
  include Bud

  state do
    # Input: the constraint that the given ID must follow the "pre" node and
    # precede the "post" node. This encodes a DAG.
    table :constr, [:id] => [:pre, :post]
    scratch :u_constr, constr.schema    # Non-sentinal constraints
    scratch :constr_prod, [:x, :y]      # Product of constr with itself

    # Output: the computed linearization of the DAG
    scratch :before, [:from, :to]
    scratch :before_tc, [:from, :to]

    # Explicit orderings
    scratch :explicit, [:from, :to]

    # Tie-breaker orderings. These are defined for all pairs a,b -- but we only
    # want to fallback to using this ordering when no other ordering information
    # is available.
    scratch :tie_break, [:from, :to]

    # Orderings implied by considering orderings between the semantic causal
    # history ("parents") of the edits from,to
    scratch :implied_parent, [:from, :to]
    scratch :implied_parent_in, [:x, :y]

    # Semantic causal history; we have [from, to] if "from" happens before "to"
    scratch :sem_hist, [:from, :to]
    scratch :sem_hist_prod, [:x_from, :x_to, :y_from, :y_to]
  end

  bootstrap do
    constr <+ [[BEGIN_ID, nil, END_ID],
               [END_ID, BEGIN_ID, nil]]
  end

  bloom :constraints do
    u_constr <= constr {|c| c unless [BEGIN_ID, END_ID].include? c.id}
    constr_prod <= (constr * constr).pairs {|c1,c2| [c1.id, c2.id]}
  end

  bloom :compute_sem_hist do
    sem_hist <= constr {|c| [c.id, c.pre] unless c.id == BEGIN_ID}
    sem_hist <= constr {|c| [c.id, c.post] unless c.id == END_ID}
    sem_hist <= (sem_hist * constr).pairs(:to => :id) do |r,c|
      [r.from, c.pre] unless c.id == BEGIN_ID
    end
    sem_hist <= (sem_hist * constr).pairs(:to => :id) do |r,c|
      [r.from, c.post] unless c.id == END_ID
    end
    sem_hist_prod <= (sem_hist * sem_hist).pairs do |h1,h2|
      [h1.from, h1.to, h2.from, h2.to]
    end
  end

  # Compute each of explicit, implied_parent, and tie_break.
  bloom :compute_candidates do
    explicit <= constr {|c| [c.pre, c.id] unless c.id == BEGIN_ID}
    explicit <= constr {|c| [c.id, c.post] unless c.id == END_ID}

    tie_break <= constr_prod {|p| [p.x, p.y] if p.x < p.y}

    implied_parent_in <= (constr_prod * sem_hist_prod).pairs(:x => :x_to, :y => :y_to) do |c,h|
      [c.x, c.y] unless explicit.include? [c.x, c.y]
    end
    implied_parent <= implied_parent_in {|i| i if i.x < i.y}
  end

  # Combine explicit, implied_parent, and tie_break to get the final
  # linearization.
  bloom :compute_final do
    before_tc <= before
    before_tc <= (before_tc * before).pairs(:to => :from) {|t,b| [t.from, b.to]}

    before <= explicit
    before <= implied_parent.notin(explicit, :from => :to, :to => :from)
    before <= tie_break.notin(implied_parent, :from => :to, :to => :from).notin(explicit, :from => :to, :to => :from)
  end
end
