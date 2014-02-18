# Simplified version of the full DiCE program: given (a) a total "tiebreak"
# order over all atoms (b) a partial order over a subset of the atoms, we want
# to construct a *monotone* linear extension of the partial order, using the
# total order for elements that the partial order regards as incomparable. The
# extension should be "monotone" in the sense that if we decide a < b at some
# time, a < b will remain true at every future time.
#
# Note that as stated, the problem is not solvable: if we can learn an arbitrary
# (acyclic) partial orders in the future, a new order might contradict a
# tiebreak order that we've used in the past. Hence, we need to place a
# restriction on how we can learn new orders in the future. Specifically, we
# require that for each atom, we learn that the atom follows (appears after)
# exactly one atom. That is, we can learn x > y and z > y, but not also x > z or
# z > x. This is similar to a "list append" program: each partial order
# describes a new element and a position in the list that the element must
# appear after. If two elements are added concurrently, they might both appear
# after the same element, so we need to use the tiebreak order to decide their
# mutual ordering.
#
# As in DiCE, the _order_ in which we consider tiebreaks is important. Consider
# a scenario in which we have B > A, C > A, and D > C. B and C are concurrent
# and need to be tiebroken. B and D are also concurrent, but we might not want
# to use the tiebreak order: if we have C > B, then D > B follows by
# transitivity. Hence, we place two restrictions on how the final order is
# computed:
#
#    (a) only compute the ordering for an atom if that atom's anchor is known
#
#    (b) when computing tiebreaks, start at the roots of the causal graph and
#        move "forward". That is, we only use the tiebreak order between X and Y
#        when we've computed the transitive consequences of applying tiebreaks
#        for the ancestors of X and Y. This is safe because restriction (a)
#        ensures that all the ancestors of X and Y are known. In the scenario
#        above, we start with {A}, then {B, C}, then {D}.
#
# Note that (a) also implies we need a "root" sentinel element that is known by
# all replicas initially.
require "rubygems"
require "bud"

LIST_START_ID = "-1"
LIST_START_TUPLE = [LIST_START_ID, nil]

class ListAppend
  include Bud

  state do
    # The explicit partial order; "id" comes after "pred". Each ID specifies
    # exactly one predecessor, but a given ID might be the predecessor to zero
    # or more other IDs. Note that the "pred" element might not immediately
    # precede "id" in the final version of the list (other edits, made locally
    # or at a remote site, might intervene). Note that this defines both a
    # partial order over the document as well as a (semantic) causal
    # relationship between IDs: X happens before Y if there is a (directed) path
    # from Y -> X in the predecessor graph.
    table :input_buf, [:id] => [:pred]
    po_table :safe, [:id, :pred]
    table :safe_tc, safe.schema

    po_scratch :cursor, safe.schema

    # Tiebreak order
    table :raw_tiebreak, safe.schema
    table :tiebreak, raw_tiebreak.schema

    # Implied-by-ancestor order
    table :implied_anc, safe.schema

    # Computed linearization
    table :ord, safe.schema
  end

  bootstrap do
    safe <+ [LIST_START_TUPLE]
  end

  stratum 0 do
    safe <= (input_buf * safe).lefts(:pred => :id)
    safe_tc <= safe
    safe_tc <= (safe * safe_tc).pairs(:pred => :id) {|s,t| [s.id, t.pred] unless t == LIST_START_TUPLE}
    raw_tiebreak <= (safe * safe).pairs {|x,y| [x.id, y.id] if x.id > y.id}
    cursor <= safe_tc

    # Check for orders implied by the ancestors of an edit. If x is an ancestor
    # of y, then x must precede y in the list order. Hence, if any edit z
    # tiebreaks _before_ x, z must also precede y.
    implied_anc <= (safe_tc * tiebreak).pairs(:pred => :id) {|s,t| [s.id, t.pred]}
  end

  stratum 2 do
    # Only use a tiebreak if we don't have another way to order the two IDs.
    tiebreak <= (cursor * raw_tiebreak).rights(:id => :id).notin(safe_tc, :id => :pred, :pred => :id).notin(implied_anc, :id => :pred, :pred => :id)

    ord <= safe_tc
    ord <= tiebreak
    ord <= implied_anc
  end
end
