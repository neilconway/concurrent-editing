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
    super opts
  end

  state do
    scratch :delta_m, [] => [:val]
    lmap :m
  end

  bootstrap do
    connect <~ [[@server, ip_port]]
  end

  bloom do
    stdio <~ to_host {|h| ["Message @ client #{@client_id}: #{h.inspect}"]}
    m <= to_host {|h| h.val}

    to_server <~ delta_m {|t| [@server, ip_port, t.val]}
    m <= delta_m {|t| t.val}
  end

  def send_update(v)
    puts "send_update: #{v.inspect}"
    sync_do {
      delta_m <+ [[v]]
    }
  end
end


class LatticeDocGUI
  def initialize(site_id, server)
    @site_id = site_id.to_i
    @server = server
    @lmap = Bud::MapLattice.new()
    @c = Client.new(@site_id, @server)
    @table = Hash.new()
    @textview
    @time = 0
    @pulled = false
  end

  def run
    @c.run_bg
    window = Gtk::Window.new(Gtk::Window::TOPLEVEL)
    window.resizable = true
    window.title = "Simple Text Editor"
    window.border_width = 10
    window.signal_connect('delete_event') { Gtk.main_quit }
    window.set_size_request(600, -1)

    ed = LatticeDocGUI.new(@site_id, @server)
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
end


if __FILE__ == $0
  server = (ARGV.length == 2) ? ARGV[1] : LatticeDocProtocol::DEFAULT_ADDR
  puts "Server address: #{server}"
  program = LatticeDocGUI.new(ARGV[0], server)
  program.run
  Gtk.main
end
