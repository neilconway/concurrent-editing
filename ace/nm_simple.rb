require 'rubygems'
require 'bud'

# Float::INFINITY only defined in MRI 1.9.2+
unless defined? Float::INFINITY
  Float::INFINITY = 1.0/0.0
end

# Sentinel edit IDs. Note that the tiebreaker for sentinels should never be
# used, so to test this we have BEGIN_ID > END_ID.
BEGIN_ID = Float::INFINITY
END_ID = -Float::INFINITY

# TODO: add-back integrity constraints
class SimpleNmLinear
  include Bud

  state do
    # Input: the constraint that the given ID must follow the "pre" node and
    # precede the "post" node. This encodes a DAG.
    table :constr, [:id] => [:pre, :post]
    scratch :constr_prod, [:x, :y]      # Product of constr with itself
    scratch :pre_constr, constr.schema  # Constraints with valid "pre" edge
    scratch :post_constr, constr.schema # Constraints with valid "post" edge

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
    # Sentinel constraints. We choose to have END be the causally first edit;
    # then BEGIN is placed before the END. Naturally these could be reversed.
    constr <+ [[BEGIN_ID, nil, END_ID],
               [END_ID, nil, nil]]
  end

  bloom :constraints do
    pre_constr <= constr {|c| c unless [BEGIN_ID, END_ID].include? c.id}
    post_constr <= constr {|c| c unless c.id == END_ID}
    constr_prod <= (constr * constr).pairs {|c1,c2| [c1.id, c2.id]}
  end

  bloom :compute_sem_hist do
    sem_hist <= pre_constr {|c| [c.id, c.pre]}
    sem_hist <= post_constr {|c| [c.id, c.post]}
    sem_hist <= (sem_hist * pre_constr).pairs(:to => :id) do |r,c|
      [r.from, c.pre]
    end
    sem_hist <= (sem_hist * post_constr).pairs(:to => :id) do |r,c|
      [r.from, c.post]
    end
    sem_hist_prod <= (sem_hist * sem_hist).pairs do |h1,h2|
      [h1.from, h1.to, h2.from, h2.to]
    end
  end

  # Compute each of explicit, implied_parent, and tie_break.
  bloom :compute_candidates do
    explicit <= pre_constr {|c| [c.pre, c.id]}
    explicit <= post_constr {|c| [c.id, c.post]}

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
