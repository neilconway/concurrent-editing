require 'rubygems'
require 'bud'

# Float::INFINITY only defined in MRI 1.9.2+
unless defined? Float::INFINITY
  Float::INFINITY = 1.0/0.0
end

# Sentinel edit IDs. Note that the tiebreaker for sentinels should never be
# used so the actual value of the sentinels is not important.
BEGIN_ID = Float::INFINITY
END_ID = -Float::INFINITY

class InvalidDocError < StandardError; end

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
    scratch :before_src, [:from, :to, :src]
    scratch :before_tc, [:from, :to]

    # Explicit orderings
    scratch :explicit, [:from, :to]
    scratch :explicit_tc, [:from, :to]

    # Tie-breaker orderings. These are defined for all pairs a,b -- but we only
    # want to fallback to using this ordering when no other ordering information
    # is available.
    scratch :tie_break, [:from, :to]

    # Orderings implied by considering orderings between the semantic causal
    # history ("parents") of the edits from,to
    scratch :implied_parent, [:from, :to]

    # Semantic causal history; we have [from, to] if "from" happens before "to"
    scratch :sem_hist, [:from, :to]
    scratch :sem_hist_prod, [:x_from, :x_to, :y_from, :y_to]

    # Invalid document state
    scratch :doc_fail, [:err]
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
    sem_hist <= pre_constr {|c| [c.pre, c.id]}
    sem_hist <= post_constr {|c| [c.post, c.id]}
    sem_hist <= (sem_hist * pre_constr).pairs(:from => :id) do |r,c|
      [c.pre, r.to]
    end
    sem_hist <= (sem_hist * post_constr).pairs(:from => :id) do |r,c|
      [c.post, r.to]
    end
    sem_hist_prod <= (sem_hist * sem_hist).pairs do |h1,h2|
      [h1.from, h1.to, h2.from, h2.to]
    end
  end

  # Compute each of explicit, implied_parent, and tie_break.
  bloom :compute_candidates do
    explicit <= pre_constr {|c| [c.pre, c.id]}
    explicit <= post_constr {|c| [c.id, c.post]}
    explicit_tc <= explicit
    explicit_tc <= (explicit_tc * explicit).pairs(:to => :from) {|t,c| [t.from, c.to]}

    tie_break <= constr_prod {|p| [p.x, p.y] if p.x < p.y}

    implied_parent <= (constr_prod * sem_hist_prod).pairs(:x => :x_to, :y => :y_to) do |c,h|
      unless explicit.include? [c.x, c.y]
        # XXX: Duplicating the tie-breaking logic here is unfortunate.
        [c.x, c.y] if c.x < c.y
      end
    end
  end

  # Combine explicit, implied_parent, and tie_break to get the final
  # linearization.
  bloom :compute_final do
    before_tc <= before
    before_tc <= (before_tc * before).pairs(:to => :from) {|t,b| [t.from, b.to]}

    before <= explicit
    before_src <= explicit {|c| c + ["explicit"]}
    before <= implied_parent.notin(explicit_tc, :from => :to, :to => :from)
    before_src <= implied_parent.notin(explicit_tc, :from => :to, :to => :from).pro {|c| c + ["implied"]}
    before <= tie_break.notin(implied_parent, :from => :to, :to => :from).notin(explicit_tc, :from => :to, :to => :from)
    before_src <= tie_break.notin(implied_parent, :from => :to, :to => :from).notin(explicit_tc, :from => :to, :to => :from).pro {|c| c + ["tiebreak"]}
  end

  bloom :check_valid do
    stdio <~ doc_fail {|e| raise InvalidDocError, e.inspect }

    # Only sentinels can have nil pre/post edges
    doc_fail <= constr {|c| [c] if c.pre.nil? && c.id != BEGIN_ID && c.id != END_ID}
    doc_fail <= constr {|c| [c] if c.post.nil? && c.id != END_ID}

    # Constraint graph should be acyclic
    doc_fail <= explicit_tc {|c| [c] if c.from == c.to}

    # Note that the above rules ensure that BEGIN is not a post edge and END is
    # not a pre edge of any constraint; this would imply either a cycle or a nil
    # edge.

    # XXX, not yet enforced: at originating site, pre/post edges should be
    # adjacent at the time a new constraint is added.

    # XXX, not yet enforced: constraints on output linearization. (Unlike the
    # input constraints, these are just checking the correctness of the
    # algorithm, not whether the input is legal.)
  end
end
