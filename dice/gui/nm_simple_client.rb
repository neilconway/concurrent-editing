require 'rubygems'
require 'bud'
require 'backports'
require 'gtk2'
require './doc_protocol'

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
  include DocProtocol

  def initialize(client_id, server, opts={})
      @client_id = client_id
      @server = server
      super opts
  end

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
    table :constr, [:id] => [:pre, :post]
    table :installed, constr.schema
    scratch :constr_prod, [:x, :y]      # Product of constr with itself
    scratch :pre_constr, constr.schema  # Constraints with a valid "pre" edge
    scratch :post_constr, constr.schema # Constraints with a valid "post" edge

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

    #Client/server stuff
    table :insert_ops, [:txt_id] => [:pre, :post, :txt]
    scratch :new_op, [:txt_id] => [:txt, :pre, :post] 

  end

  bootstrap do
    # Sentinel constraints. We choose to have END be the causally first edit;
    # then BEGIN is placed before END. Naturally these could be reversed.
    constr <+ [[BEGIN_ID, nil, END_ID],
               [END_ID, nil, nil]]
    installed <+ [[BEGIN_ID, nil, END_ID],
                  [END_ID, nil, nil]]
    #connects to server
    connect <~ [[@server, ip_port]]
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
    #stdio <~ to_deliver {|c| ["to_deliver @ #{budtime}: #{c}"]}
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
    #stdio <~ before {|b| ["Before: #{b.inspect}"]}
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

  bloom :talk_to_server do
    stdio <~ to_host {|h| ["Message @ client #{@client_id}: #{h.inspect}"]}
    insert_ops <= to_host {|h| [h.txt_id, h.pre, h.post, h.txt]}
    stdio <~ insert_ops {|i| ["Insert ops: #{i.inspect}"]}

    to_server <~ new_op {|i| [@server, ip_port, i.txt_id, i.pre, i.post, i.txt]}
    insert_ops <= new_op {|n| [n.txt_id, n.txt, n.pre, n.post]}
  end

  def send_update(txt_id, txt, pre, post)
    puts "send_update: #{txt.inspect}"
    sync_do {
      new_op <+ [[txt_id, pre, post, txt]]
    }
  end
end

class Gui
  def initialize(site_id, server)
    @site_id = site_id.to_i
    @server = server
    @client = SimpleNmLinear.new(@site_id, @server)
    @id_lookup_table = Hash.new()
    @next_id = 0
    @easy_text_lookup = Hash.new()
  end

  def run()
    @client.run_bg
    @id_lookup_table[0]=-1
    window = Gtk::Window.new(Gtk::Window::TOPLEVEL)
    window.resizable = true
    window.title = "DICE"
    window.border_width = 10
    window.signal_connect('delete_event') { Gtk.main_quit }
    window.set_size_request(600, -1)

    ed = Gui.new(@site_id, @server)
    @textview = Gtk::TextView.new

      pull = Gtk::Button.new("Pull")

    pull.signal_connect("clicked") { pull_clicked(ed) }

    scrolled_win = Gtk::ScrolledWindow.new
    scrolled_win.border_width = 5
    scrolled_win.add(@textview)
    scrolled_win.set_policy(Gtk::POLICY_AUTOMATIC, Gtk::POLICY_ALWAYS)

    vbox = Gtk::VBox.new(true, 5)
    vbox.pack_start(pull, false, false, 0)

    table = Gtk::Table.new(2, 2, false)

    table.attach(scrolled_win, 0, 1, 0, 1, 
             Gtk::EXPAND | Gtk::FILL, Gtk::EXPAND | Gtk::FILL, 5, 5)
    table.attach(vbox, 1, 2, 0, 1, 
             Gtk::SHRINK, Gtk::SHRINK, 5, 5)

    window.add(table)
    window.show_all

    @textview.buffer.signal_connect("insert-text") do |buf, it, txt, len|
      if len > 1
        @pulled = true
      end
    end

    @textview.buffer.signal_connect_after("insert-text") do |buf, it, txt, len|
      if @pulled
        @pulled = false
      else
        txt_id = @next_id.to_s + "." + @site_id.to_s
        p txt_id
        txt_id = txt_id.to_f
        p "ID LOOKUP TABLE BEFORE"
        p @id_lookup_table
        p "offset"
        p it.offset
        @id_lookup_table = update_table(@id_lookup_table, it.offset, txt_id)
        p "ID LOOKUP TABLE NOW:"
        p @id_lookup_table
        @easy_text_lookup[txt_id] = txt
        @next_id = @next_id + 1
        post_id = @id_lookup_table[it.offset + 1]
        pre_id = @id_lookup_table[it.offset - 1]
        p "PRE ID LOOKUP"
        p @id_lookup_table[it.offset - 1]
        if post_id == nil
          post_id = END_ID
        end
        if pre_id == nil or pre_id == -1
          pre_id = BEGIN_ID
        end
        p "POST: "
        p post_id
        p "PRE: "
        p pre_id
        @client.send_update(txt_id, txt, pre_id, post_id)
        @client.input_buf <+ [[txt_id, pre_id, post_id]]
        @client.tick
        p "BEFORE: "
        p @client.before.to_a.sort
        @pulled = false
      end
    end 
  end

  def update_table(table, offset, id)
    newTable= Hash.new
    for key in table.keys.sort
      if key < offset
        newTable[key] = table[key]
      else
        newTable[key+1] = table[key]
      end
    end
    newTable[offset] = id
    return newTable
  end

  def create_table(linear_order)
    table = Hash.new()
    offset = 1
    for id in linear_order
      if id != BEGIN_ID and id != END_ID
        table[offset] = id
        offset += 1
      end
    end
    return table
  end

  def pull_clicked(ed)
    @pulled = true
    @client.input_buf <+ @client.insert_ops {|i| [i.txt_id, i.pre, i.post]}
    100.times { |i| @client.tick }

    linear = linearize(@client.before.to_a.sort)
    p "BEFORE"
    p @client.before.to_a.sort
    p "LINEAR: "
    p linear
    keys = @client.insert_ops.keys
    values = @client.insert_ops.values
    for i in 0..keys.length - 1
      @easy_text_lookup[keys[i][0]] = values[i][2]
    end
    text = ""
    for l in linear
      if l != BEGIN_ID and l != END_ID
        text = text + @easy_text_lookup[l]
      end
    end

    @id_lookup_table = create_table(linear)
    p @id_lookup_table
    @textview.buffer.text = text


  end

  def insert_before(arr, item, index)
    first_part = arr[0..index - 1]
    second_part = [item].concat(arr[index..arr.size - 1])
    return first_part.concat(second_part)
  end

   def linearize(constraints)
    linear = [BEGIN_ID, END_ID]
    before_index = nil
    after_index = nil
    for c in constraints
      for i in 0..linear.size - 1
        if linear[i] == c[0]
          before_index = i
        elsif linear[i] == c[1]
          after_index = i
        end
      end
      if before_index != nil and after_index == nil
        linear = insert_before(linear, c[1], before_index + 1)
      elsif before_index == nil and after_index != nil
        linear = insert_before(linear, c[0], after_index)
      elsif before_index == nil and after_index == nil
        linear = insert_before(linear, [c[0], c[1]], linear.size - 1)
      elsif before_index != nil and after_index != nil
        if before_index > after_index
          temp = linear[before_index]
          linear.delete(temp)
          linear = insert_before(linear, temp, after_index)
        end
      end
      before_index = nil
      after_index = nil
    end
    return linear
  end
end


if __FILE__ == $0
  server = (ARGV.length == 2) ? ARGV[1] : DocProtocol::DEFAULT_ADDR
  puts "Server address: #{server}"
  program = Gui.new(ARGV[0], server)
  #program = LatticeDocGUI.new(ARGV[0])
  program.run
  Gtk.main
end