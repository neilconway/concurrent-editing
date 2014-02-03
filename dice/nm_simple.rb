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

class SimpleNmLinear
  include Bud

  state do
    # Input buffer. Edit operations arrive here; once the dependencies of an
    # edit have been delivered, the edit itself can be delivered to "constr" and
    # removed from the buffer. In other words, the buffer ensures that
    # (semantic) causal delivery is respected.
    table :input_buf, [:id] => [:pre, :post]
    scratch :input_has_pre, input_buf.schema
    scratch :input_has_post, input_buf.schema
    scratch :to_deliver, input_buf.schema

    # The constraint that the given ID must follow the "pre" node and precede
    # the "post" node. This encodes a DAG. "installed" is essentially
    # constr@prev; i.e., all the constraints that have been installed in
    # timesteps before the current one.
    table :constr, to_deliver.schema
    table :installed, constr.schema
    scratch :pre_constr, constr.schema  # Constraints with a valid "pre" edge
    scratch :post_constr, constr.schema # Constraints with a valid "post" edge
    scratch :constr_prod, [:x, :y]      # Product of constr with itself

    # Output: the computed linearization of the DAG
    scratch :before, [:from, :to]

    # Explicit orderings
    scratch :explicit, [:from, :to]
    scratch :explicit_tc, [:from, :to]

    # Tiebreaker orderings. These are defined for all pairs a,b -- but we only
    # want to fallback to using this ordering when no other ordering information
    # is available.
    scratch :tiebreak, [:from, :to]
    scratch :use_tiebreak, [:from, :to]

    # Orderings implied by considering tiebreaks between the semantic causal
    # history ("ancestors") of the edits from,to
    scratch :implied_anc, [:from, :to]
    scratch :use_implied_anc, [:from, :to]

    # Semantic causal history; we have [from, to] if "from" happens before "to"
    scratch :sem_hist, [:from, :to]

    # Invalid document state
    scratch :doc_fail, [:err]
  end

  bootstrap do
    # Sentinel constraints. We choose to have END be the causally first edit;
    # then BEGIN is placed before END. Naturally these could be reversed.
    constr <+ [[BEGIN_ID, nil, END_ID],
               [END_ID, nil, nil]]
    installed <+ [[BEGIN_ID, nil, END_ID],
                  [END_ID, nil, nil]]
  end

  bloom :buffering do
    input_has_pre <= (input_buf * installed).lefts(:pre => :id)
    input_has_post <= (input_has_pre * installed).lefts(:post => :id)
    # XXX: gross hack. For now, we only deliver a single eligible edit per
    # timestep (we use the edit with the smallest ID but that is arbitrary).
    to_deliver <= input_has_post.argmin(nil, :id)
    constr <= to_deliver
    input_buf <- to_deliver
    installed <+ constr
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
  end

  # Compute each of explicit, implied_anc, and tiebreak.
  bloom :compute_candidates do
    explicit <= pre_constr {|c| [c.pre, c.id]}
    explicit <= post_constr {|c| [c.id, c.post]}
    explicit_tc <= explicit
    explicit_tc <= (explicit_tc * explicit).pairs(:to => :from) {|t,c| [t.from, c.to]}

    tiebreak <= constr_prod {|p| [p.x, p.y] if p.x < p.y}
    # We only want to use tiebreak orderings when no other order is available
    use_tiebreak <+ tiebreak.notin(use_implied_anc, :from => :to, :to => :from).notin(explicit_tc, :from => :to, :to => :from)

    # Infer the orderings over child nodes implied by their ancestors. We look
    # for two cases:
    #
    #   1. y is an ancestor of x, there is a tiebreak y < z, and there is an
    #      explicit constraint x < y; this implies x < z
    #
    #   2. y is an ancestor of x, there is a tiebreak z < y, and there is an
    #      explicit constraint y < x; this implies z < x.
    implied_anc <= (sem_hist * use_tiebreak * explicit_tc).combos(sem_hist.from => use_tiebreak.from,
                                                                  sem_hist.to => explicit_tc.from,
                                                                  sem_hist.from => explicit_tc.to) do |s,t,e|
      [s.to, t.to]
    end
    implied_anc <= (sem_hist * use_tiebreak * explicit_tc).combos(sem_hist.from => use_tiebreak.to,
                                                                  sem_hist.to => explicit_tc.to,
                                                                  sem_hist.from => explicit_tc.from) do |s,t,e|
      [t.from, s.to]
    end
    use_implied_anc <= implied_anc.notin(explicit_tc, :from => :to, :to => :from)
  end

  # Combine explicit, implied_anc, and tiebreak to get the final order.
  bloom :compute_final do
    before <= explicit_tc
    before <= use_implied_anc
    before <= use_tiebreak
  end

  bloom :check_valid do
    stdio <~ doc_fail {|e| raise InvalidDocError, e.inspect }

    # Only sentinels can have nil pre/post edges, but those never appear in the
    # input_buf. (Raising an error here isn't strictly necessary; such malformed
    # inputs would never be removed from input_buf anyway.)
    doc_fail <= input_buf {|c| [c] if c.pre.nil? || c.post.nil?}

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
