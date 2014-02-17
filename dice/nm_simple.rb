require 'rubygems'
require 'bud'

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

    # The constraint that the given ID must follow the "pre" node and precede
    # the "post" node. This encodes a DAG.
    table :constr, input_buf.schema
    scratch :pre_constr, constr.schema  # Constraints with a valid "pre" edge
    scratch :post_constr, constr.schema # Constraints with a valid "post" edge

    # Output: the computed linearization of the DAG
    table :ord, [:id, :pred]

    # Explicit orderings
    table :explicit, [:id, :pred]
    table :explicit_tc, explicit.schema

    # Tiebreaker orderings. These are defined for all pairs a,b -- but we only
    # want to fallback to using this ordering when no other ordering information
    # is available.
    table :tiebreak, [:id, :pred]
    scratch :use_tiebreak, tiebreak.schema
    scratch :tmp_tiebreak, use_tiebreak.schema

    # Orderings implied by considering tiebreaks between the semantic causal
    # history ("ancestors") of the edits from,to
    table :implied_anc, [:id, :pred]
    table :implied_anc1, [:id, :pred]
    table :implied_anc2, [:id, :pred]
    table :use_implied_anc, implied_anc.schema

    # Semantic causal history; we have [from, to] if "from" happens before "to"
    poset :sem_hist, [:to, :from]
    po_scratch :cursor, sem_hist.schema
    scratch :to_check, [:x, :y]

    # Invalid document state
    scratch :doc_fail, [:err]
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

    explicit <= pre_constr {|c| [c.id, c.pre]}
    explicit <= post_constr {|c| [c.post, c.id]}
    explicit_tc <= explicit
    explicit_tc <= (explicit * explicit_tc).pairs(:pred => :id) {|e,t| [e.id, t.pred]}

#    tiebreak <= (constr * constr).pairs {|c1,c2| [c1.id, c2.id] if c1.id > c2.id}
    tiebreak <= (sem_hist * sem_hist).pairs {|c1,c2| [c1.from, c2.from] if c1.from > c2.from}
    tiebreak <= (sem_hist * sem_hist).pairs {|c1,c2| [c1.to, c2.to] if c1.to > c2.to}
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
    implied_anc1 <= (to_check * sem_hist * use_tiebreak * explicit_tc).combos(to_check.x => sem_hist.to,
                                                                              to_check.y => use_tiebreak.id,
                                                                              sem_hist.from => use_tiebreak.pred,
                                                                              sem_hist.to => explicit_tc.pred,
                                                                              sem_hist.from => explicit_tc.id) do |tc,s,t,e|
      puts "IMPLIED_ANC1A: #{[t.id, s.to]}"; [t.id, s.to]
    end
    implied_anc1 <= (to_check * sem_hist * use_tiebreak * explicit_tc).combos(to_check.y => sem_hist.to,
                                                                              to_check.x => use_tiebreak.id,
                                                                              sem_hist.from => use_tiebreak.pred,
                                                                              sem_hist.to => explicit_tc.pred,
                                                                              sem_hist.from => explicit_tc.id) do |tc,s,t,e|
      puts "IMPLIED_ANC1B: #{[t.id, s.to]}"; [t.id, s.to]
    end
    implied_anc2 <= (to_check * sem_hist * use_tiebreak * explicit_tc).combos(to_check.x => sem_hist.to,
                                                                              to_check.y => use_tiebreak.pred,
                                                                              sem_hist.from => use_tiebreak.id,
                                                                              sem_hist.to => explicit_tc.id,
                                                                              sem_hist.from => explicit_tc.pred) do |tc,s,t,e|
      puts "IMPLIED_ANC2A: #{[t.id, s.to]}"; [s.to, t.pred]
    end
    implied_anc2 <= (to_check * sem_hist * use_tiebreak * explicit_tc).combos(to_check.y => sem_hist.to,
                                                                              to_check.x => use_tiebreak.pred,
                                                                              sem_hist.from => use_tiebreak.id,
                                                                              sem_hist.to => explicit_tc.id,
                                                                              sem_hist.from => explicit_tc.pred) do |tc,s,t,e|
      puts "IMPLIED_ANC2B: #{[t.id, s.to]}"; [s.to, t.pred]
    end
    implied_anc <= implied_anc1
    implied_anc <= implied_anc2
  end

  stratum 2 do
    use_implied_anc <= implied_anc.notin(explicit_tc, :id => :pred, :pred => :id)
  end

  stratum 3 do
#    use_tiebreak <= tiebreak.notin(use_implied_anc, :id => :pred, :pred => :id).notin(explicit_tc, :id => :pred, :pred => :id)
#    use_tiebreak <= (cursor * tiebreak).rights(:to => :id).notin(use_implied_anc, :id => :pred, :pred => :id).notin(explicit_tc, :id => :pred, :pred => :id).pro {|t| puts "USE_TIE: #{t}"; t}
    # tmp_tiebreak <= (cursor * tiebreak).pairs(:to => :id) {|c,t| puts "PASSED CURSOR CHECK (1): c = #{c}, t = #{t}"; t}
    # tmp_tiebreak <= (cursor * tiebreak).pairs(:to => :pred) {|c,t| puts "PASSED CURSOR CHECK (2): c = #{c}, t = #{t}"; t}
#    tmp_tiebreak <= (cursor * cursor).pairs {|x,y| [x.to, y.to] if x.to > y.to}
#   tmp_tiebreak <= (cursor * sem_hist).pairs(:from => :from) {|x,y| puts "CHECK: #{x}, #{y}}"; [x.to, y.to] if x.to > y.to}
    # tmp_tiebreak <= (cursor * cursor).pairs {|x,y| [x.to, y.to] if x.to > y.to}
    # tmp_tiebreak <= (cursor * cursor).pairs {|x,y| [y.to, x.to] if x.to < y.to}
#   tmp_tiebreak <= (cursor * sem_hist).pairs(:to => :to) {|x,y| [y.from, x.to] if x.to < y.from}
    tmp_tiebreak <= to_check {|c| [c.x, c.y] if c.x > c.y}
    tmp_tiebreak <= to_check {|c| [c.y, c.x] if c.x < c.y}
    use_tiebreak <= tmp_tiebreak.notin(use_implied_anc, :id => :pred, :pred => :id).notin(explicit_tc, :id => :pred, :pred => :id).pro {|t| puts "USE_TIE: #{t}"; t}
  end

  stratum 4 do
    ord <= explicit_tc
    ord <= use_implied_anc
    ord <= use_tiebreak

    stdio <~ doc_fail {|e| raise InvalidDocError, e.inspect }

    # Only sentinels can have nil pre/post edges, but those never appear in the
    # input_buf. (Raising an error here isn't strictly necessary; such malformed
    # inputs would never be removed from input_buf anyway.)
    doc_fail <= input_buf {|c| [c] if c.pre.nil? || c.post.nil?}

    # Constraint graph should be acyclic
    doc_fail <= explicit_tc {|c| [c] if c.pred == c.id}

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
