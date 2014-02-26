require 'rubygems'
require 'bud'

# Sentinel edit IDs. Note that the tiebreaker for sentinels should never be
# used so the actual value of the sentinels is not important.
BEGIN_ID = Float::INFINITY
END_ID = -Float::INFINITY

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

    # The constraint that the given ID must follow the "pre" node and precede
    # the "post" node. This encodes a DAG.
    table :constr, input_buf.schema
    scratch :pre_constr, constr.schema  # Constraints with a valid "pre" edge
    scratch :post_constr, constr.schema # Constraints with a valid "post" edge

    # Output: the computed linearization of the DAG
    table :ord, [:id, :pred]

    # Explicit orderings
    table :explicit, ord.schema
    table :explicit_tc, explicit.schema

    # Tiebreaker orderings. These are defined for all pairs a,b -- but we only
    # want to fallback to using this ordering when no other ordering information
    # is available.
    table :tiebreak, ord.schema
    scratch :tmp_tiebreak, tiebreak.schema

    # Orderings implied by considering tiebreaks between the semantic causal
    # history ("ancestors") of the edits from,to
    table :implied_anc, ord.schema

    # Semantic causal history; we have [from, to] if "from" happens before "to"
    po_table :sem_hist, [:to, :from]
    po_scratch :cursor, sem_hist.schema
    scratch :to_check, [:x, :y]
  end

  bootstrap do
    # Sentinel constraints. We choose to have END be the causally first edit;
    # then BEGIN is placed before END. Naturally these could be reversed.
    constr <+ [[BEGIN_ID, nil, END_ID],
               [END_ID, nil, nil]]
  end

  stratum 0 do
    input_has_pre <= (input_buf * constr).lefts(:pre => :id)
    input_has_post <= (input_has_pre * constr).lefts(:post => :id)
    constr <= input_has_post

    pre_constr <= constr {|c| c unless [BEGIN_ID, END_ID].include? c.id}
    post_constr <= constr {|c| c unless c.id == END_ID}

    sem_hist <= pre_constr {|c| [c.id, c.pre]}
    sem_hist <= post_constr {|c| [c.id, c.post]}
    sem_hist <= (pre_constr * sem_hist).pairs(:pre => :to) do |c,r|
      [c.id, r.from]
    end
    sem_hist <= (post_constr * sem_hist).pairs(:post => :to) do |c,r|
      [c.id, r.from]
    end
    cursor <= sem_hist

    to_check <= (cursor * sem_hist).pairs {|c,s| [c.to, s.to] if c.to != s.to}
    to_check <= (cursor * sem_hist).pairs {|c,s| [s.to, c.to] if c.to != s.to}

    explicit <= pre_constr {|c| [c.id, c.pre]}
    explicit <= post_constr {|c| [c.post, c.id]}
    explicit_tc <= explicit
    explicit_tc <= (explicit * explicit_tc).pairs(:pred => :id) {|e,t| [e.id, t.pred]}
  end

  stratum 1 do
    # Infer the orderings over child nodes implied by their ancestors. We look
    # for two cases:
    #
    #   1. y is an ancestor of x, there is a tiebreak y < z, and there is an
    #      explicit constraint x < y; this implies x < z
    #
    #   2. y is an ancestor of x, there is a tiebreak z < y, and there is an
    #      explicit constraint y < x; this implies z < x.
    implied_anc <= (to_check * sem_hist * tiebreak * explicit_tc).combos(to_check.x => sem_hist.to,
                                                                         to_check.y => tiebreak.id,
                                                                         sem_hist.from => tiebreak.pred,
                                                                         sem_hist.to => explicit_tc.pred,
                                                                         sem_hist.from => explicit_tc.id) do |tc,s,t,e|
      [t.id, s.to]
    end
    implied_anc <= (to_check * sem_hist * tiebreak * explicit_tc).combos(to_check.x => sem_hist.to,
                                                                         to_check.y => tiebreak.pred,
                                                                         sem_hist.from => tiebreak.id,
                                                                         sem_hist.to => explicit_tc.id,
                                                                         sem_hist.from => explicit_tc.pred) do |tc,s,t,e|
      [s.to, t.pred]
    end
  end

  stratum 2 do
    tmp_tiebreak <= to_check {|c| [c.x, c.y] if c.x > c.y}
    tmp_tiebreak <= to_check {|c| [c.y, c.x] if c.x < c.y}
    tiebreak <= tmp_tiebreak.notin(implied_anc, :id => :pred, :pred => :id).notin(explicit_tc, :id => :pred, :pred => :id)

    ord <= explicit_tc
    ord <= implied_anc
    ord <= tiebreak
  end
end
