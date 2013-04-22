require 'rubygems'
require 'bud'
require 'backports'
require 'gtk2'
require './doc_protocol'
require '../nm_simple'

# Float::INFINITY only defined in MRI 1.9.2+
unless defined? Float::INFINITY
  Float::INFINITY = 1.0/0.0
end

class InvalidDocError < StandardError; end

class Client
  include Bud
  include DocProtocol

  def initialize(client_id, server, opts={})
      @client_id = client_id
      @server = server 
      super opts
  end

  state do 
    table :insert_ops, [:txt_id] => [:pre, :post, :txt]
    scratch :new_op, [:txt_id] => [:txt, :pre, :post]
  end

  bootstrap do
    connect <~ [[@server, ip_port]]
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
    @client = Client.new(@site_id, @server)
    @id_lookup_table = Hash.new()
    @next_id = 0
    @easy_text_lookup = Hash.new()
    @nmLinear = SimpleNmLinear.new()
  end

  def run()
    @client.run_bg
    @nmLinear.run_bg
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

    @textview.buffer.signal_connect_after("insert-text") do |buf, it, txt, len|
      if @pulled
        @pulled = false
      else
        txt_id = @next_id.to_s + "." + @site_id.to_s
        txt_id = txt_id.to_f
        @id_lookup_table = update_table(@id_lookup_table, it.offset, txt_id)
        @easy_text_lookup[txt_id] = txt
        @next_id = @next_id + 1
        post_id = @id_lookup_table[it.offset + 1]
        pre_id = @id_lookup_table[it.offset - 1]
        if post_id == nil
          post_id = END_ID
        end
        if pre_id == nil or pre_id == -1
          pre_id = BEGIN_ID
        end
        @client.send_update(txt_id, txt, pre_id, post_id)
        @nmLinear.input_buf <+ [[txt_id, pre_id, post_id]]
        @nmLinear.tick
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
    @nmLinear.input_buf <+ @client.insert_ops {|i| [i.txt_id, i.pre, i.post]}
    tick_times = @client.insert_ops.to_a.size + 2
    tick_times.times { |i| @nmLinear.tick }

    linear = linearize(@nmLinear.before.to_a.sort)
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
  program.run
  Gtk.main
end