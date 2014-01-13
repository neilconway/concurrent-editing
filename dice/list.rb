require 'rubygems'
require 'bud'

# Float::INFINITY only defined in MRI 1.9.2+
unless defined? Float::INFINITY
  Float::INFINITY = 1.0/0.0
end

BEGIN_NODE = -Float::INFINITY
END_NODE = Float::INFINITY

class SimpleList
  include Bud

  state do
    table :link, [:from] => [:to]
    table :constr, [:id] => [:pre, :post]

    scratch :ins_init, [:id]
    scratch :ins_state, [:id, :curr] => [:stop]
    scratch :peer_cnt, [:id] => [:cnt]
    scratch :do_insert, [:id] => [:prev, :next]
  end

  bootstrap do
  end

  bloom do
    # Starting at the "pre" constraint, walk forward in document order until we
    # see the "post" constraint
    ins_state <= (ins_init * constr).pairs(:id => :id) {|i,c| [i.id, c.pre, c.post]}
    ins_state <= (ins_state * link).pairs(:curr => :from) {|s,l| [s.id, l.to, s.stop] unless l.from == s.stop}

    peer_cnt <= ins_state.group(:id, count)
    # If there are no other nodes between the pre and post constraints, we're
    # done. We want to update the linked list -- (a) insert id.next =
    # id.pre.next (b) update id.pre.next = id
    do_insert <= (peer_cnt * constr).pairs(:id => :id) {|p,c| c if p.cnt == 2}
    # XXX: we insert c.next but delete the old c.prev; this assumes the old
    # c.prev.next = c.next
    link <= do_insert {|i| [c.id, c.next]}
    link <- (do_insert * link).rights(:prev => :from)
    link <+ do_insert {|i| [c.prev, c.id]}

    # Otherwise, decide how to order the new insertion with respect to the other
    # edits in the [pre, post] range.
  end
end
