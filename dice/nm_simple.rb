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
    # edit are safe, the edit itself can be delivered to "safe" and removed from
    # the buffer. In other words, the buffer ensures that (semantic) causal
    # delivery is respected.
    table :input_buf, [:id] => [:pre, :post]
    scratch :input_has_pre, input_buf.schema

    # The constraint that the given ID must follow the "pre" node and precede
    # the "post" node. This encodes a DAG.
    table :safe, input_buf.schema

    # Semantic causal history; we have [from, to] if "from" happens before "to"
    po_table :causal_ord, [:to, :from]
    po_scratch :cursor, causal_ord.schema
    scratch :to_check, [:x, :y]

    # Explicit orderings
    table :explicit, [:id, :pred]
    table :explicit_tc, explicit.schema

    # Tiebreaker orderings. These are defined for all pairs a,b -- but we only
    # want to fallback to using this ordering when no other ordering information
    # is available.
    scratch :check_tie, explicit.schema
    table :tiebreak, explicit.schema

    # Orderings implied by considering tiebreaks between the semantic causal
    # history ("ancestors") of the edits from,to
    table :implied_anc, explicit.schema

    # Output: the computed linearization of the DAG
    table :ord, explicit.schema
  end

  bootstrap do
    # Sentinels. We choose to have END be the causally first edit; then BEGIN is
    # placed before END. Naturally these could be reversed.
    safe <+ [[BEGIN_ID, nil, END_ID], [END_ID, nil, nil]]
  end

  stratum 0 do
    input_has_pre <= (input_buf * safe).lefts(:pre => :id)
    safe <= (input_has_pre * safe).lefts(:post => :id)

    causal_ord <= safe {|s| [s.id, s.pre] unless s.pre.nil?}
    causal_ord <= safe {|s| [s.id, s.post] unless s.post.nil?}
    causal_ord <= (safe * causal_ord).pairs(:pre => :to) do |s,r|
      [s.id, r.from]
    end
    causal_ord <= (safe * causal_ord).pairs(:post => :to) do |s,r|
      [s.id, r.from]
    end
    cursor <= causal_ord

    to_check <= (cursor * causal_ord).pairs {|c,s| [c.to, s.to] if c.to != s.to}
    to_check <= (cursor * causal_ord).pairs {|c,s| [s.to, c.to] if c.to != s.to}

    explicit <= safe {|s| [s.id, s.pre] unless s.pre.nil?}
    explicit <= safe {|s| [s.post, s.id] unless s.post.nil?}
    explicit_tc <= explicit
    explicit_tc <= (explicit * explicit_tc).pairs(:pred => :id) {|e,t| [e.id, t.pred]}

    # Infer the orderings over child nodes implied by their ancestors. We look
    # for two cases:
    #
    #   1. y is an ancestor of x, there is a tiebreak y < z, and there is an
    #      explicit constraint x < y; this implies x < z
    #
    #   2. y is an ancestor of x, there is a tiebreak z < y, and there is an
    #      explicit constraint y < x; this implies z < x.
    implied_anc <= (to_check * causal_ord * tiebreak * explicit_tc).combos(to_check.x => causal_ord.to,
                                                                           to_check.y => tiebreak.id,
                                                                           causal_ord.from => tiebreak.pred,
                                                                           causal_ord.to => explicit_tc.pred,
                                                                           causal_ord.from => explicit_tc.id) do |tc,c,t,e|
      [t.id, c.to]
    end
    implied_anc <= (to_check * causal_ord * tiebreak * explicit_tc).combos(to_check.x => causal_ord.to,
                                                                           to_check.y => tiebreak.pred,
                                                                           causal_ord.from => tiebreak.id,
                                                                           causal_ord.to => explicit_tc.id,
                                                                           causal_ord.from => explicit_tc.pred) do |tc,c,t,e|
      [c.to, t.pred]
    end
  end

  stratum 1 do
    # Only use a tiebreak if we don't have another way to order the two IDs.
    check_tie <= to_check {|c| [[c.x, c.y].max, [c.x, c.y].min]}
    tiebreak <= check_tie.notin(implied_anc, :id => :pred, :pred => :id).notin(explicit_tc, :id => :pred, :pred => :id)

    ord <= explicit_tc
    ord <= implied_anc
    ord <= tiebreak
  end
end
