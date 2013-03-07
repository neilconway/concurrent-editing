#!/usr/bin/env ruby
require 'rubygems'
require 'backports'
require 'bud'
require 'gtk2'
require 'pp'
require_relative 'doc_protocol'
require_relative 'lfixed'
require_relative 'logoot_lattice'

class Client
  include Bud
  include LatticeDocProtocol

  def initialize(client_id, server, opts={})
    @client_id = client_id
    @server = server
    @current_doc = nil
    super opts
  end

  state do
    scratch :delta_m, [] => [:val]
    scratch :new_doc, [] => [:val]
    scratch :doc, [] => [:val]
    lmap :m
    table :my_docs
  end

  bootstrap do
    connect <~ [[@server, ip_port]]
  end

  bloom do
    stdio <~ to_host {|h| ["Message @ client #{@client_id}: #{h.inspect}"]}
    my_docs <= list_of_docs_to_client {|c| [c.val]}
    new_doc_to_server <~ new_doc {|n| [@server, ip_port, n.val]}
    select_doc_to_server <~ doc {|d| [@server, ip_port, d.val]}
    m <= to_host {|h| h.val if h.doc_name == @current_doc}
    to_server <~ delta_m {|t| [@server, ip_port, @current_doc, t.val]}
    m <= delta_m {|t| t.val}
  end

  def send_update(v)
    #puts "send_update: #{v.inspect}"
    sync_do {
      delta_m <+ [[v]]
    }
  end

  def create_new_doc(name)
    sync_do {
      new_doc <+ [[name]]
    }
  end

  def set_current_doc(name)
    @current_doc = name
  end

  def pick_existing_doc(name)
     sync_do {
      doc <+ [[name]]
    }
  end
end


class LatticeDocGUI
  def initialize(site_id)
    @site_id = site_id.to_i
    @server = nil
    @lmap = Bud::MapLattice.new()
    @c = nil
    @table = Hash.new()
    @textview
    @time = 0
    @pulled = false
    @docs = []
    @current_doc
  end

  def run
    run_set_up()
    #run_editor()
  end

  def run_set_up
    window = Gtk::Window.new(Gtk::Window::TOPLEVEL)
    window.set_title  "Set up server"
    window.border_width = 10
    window.signal_connect('delete_event') { Gtk.main_quit }
  
    entry_label_server = Gtk::Label.new("Server:")

    server = Gtk::Entry.new
    connect = Gtk::Button.new("Connect")

    hbox = Gtk::HBox.new(false, 5)
    hbox.pack_start_defaults(entry_label_server)
    hbox.pack_start_defaults(server)
    hbox.pack_start_defaults(connect)
    vbox = Gtk::VBox.new(false, 5)
    vbox.pack_start_defaults(hbox)

    connect.signal_connect("clicked") do |b|
      @server = server.text
      @c = Client.new(@site_id, @server)
      @c.run_bg
      run_pick_doc()
      #run_editor()

    end

    window.add(vbox)
    window.show_all
  end

  def run_pick_doc
    window = Gtk::Window.new(Gtk::Window::TOPLEVEL)
    window.title = "Pick your document"
    flag = false

    # THIS IS WAY TOO HACKY!
    sleep(1)

    refresh_doc_list()

    cb = Gtk::ComboBox.new
    for doc in @docs
      cb.append_text(doc[0])
    end
    select_existing = Gtk::Button.new("Select existing document")
    create = Gtk::Button.new("Create new document")
    new_doc_name = Gtk::Entry.new
    create.signal_connect("clicked") do |c|
      @current_doc = new_doc_name.text
      @c.create_new_doc(@current_doc)
      @c.set_current_doc(@current_doc)
      run_editor()
    end
    select_existing.signal_connect("clicked") do |s|
      @current_doc = cb.active_text
      @c.set_current_doc(@current_doc)
      @c.pick_existing_doc(@current_doc)
      run_editor()
    end
    hbox = Gtk::HBox.new(false, 5)
    hbox.pack_start_defaults(cb)
    hbox.pack_start_defaults(select_existing)
    hbox.pack_start_defaults(new_doc_name)
    hbox.pack_start_defaults(create)
    vbox = Gtk::VBox.new(false, 5)
    vbox.pack_start_defaults(hbox)
    window.add(vbox)
    window.show_all
  end

  def run_editor
    #@c.run_bg
    window = Gtk::Window.new(Gtk::Window::TOPLEVEL)
    window.resizable = true
    window.title = "Simple Text Editor"
    window.border_width = 10
    window.signal_connect('delete_event') { Gtk.main_quit }
    window.set_size_request(600, -1)

    p @server
    ed = LatticeDocGUI.new(@site_id)
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
        @time += 1
        delta = createDelta(txt, it.offset, @table, @site_id, @time)
        @lmap = @lmap.merge(delta)
        @c.send_update(@lmap)
        @table = createTable(@lmap, getPaths(@lmap).reverse,0)
        #p @table
        @pulled = false
      end
    end

    @textview.buffer.signal_connect("delete-range") do |buf, i1, i2|
      if not @pulled
        @time += 1
        delta = createDocLattice(@table[i2.offset][1], -1)
        @lmap = @lmap.merge(delta)
        @c.send_update(@lmap)
        paths = getPaths(@lmap)
        @table = createTable(@lmap, paths.reverse, 0)
        #p @table
      else
        @pulled = false
      end
    end
  end

  def pull_clicked(te)
    @pulled = true
    @c.sync_do {
      @lmap = @c.m.current_value
    }
    paths = getPaths(@lmap)
    @table = createTable(@lmap, paths.reverse, 0)
    @textview.buffer.text = ""
    initialDoc = ""
    for key in @table.keys.sort
      initialDoc = initialDoc + @table[key][0]
    end
    @textview.buffer.text = initialDoc
  end

  def refresh_lmap()
    @c.sync_do {
      @lmap = @c.m.current_value
    }
  end

  def refresh_doc_list()
    @c.sync_do {
      @docs = @c.my_docs.keys
    }
  end
end


if __FILE__ == $0
  #server = (ARGV.length == 2) ? ARGV[1] : LatticeDocProtocol::DEFAULT_ADDR
  #puts "Server address: #{server}"
  #program = LatticeDocGUI.new(ARGV[0], server)
  program = LatticeDocGUI.new(ARGV[0])
  program.run
  Gtk.main
end
