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

    push = Gtk::Button.new("Push")
    pull = Gtk::Button.new("Pull")

    push.signal_connect("clicked") { push_clicked(ed) }
    pull.signal_connect("clicked") { pull_clicked(ed) }

    scrolled_win = Gtk::ScrolledWindow.new
    scrolled_win.border_width = 5
    scrolled_win.add(@textview)
    scrolled_win.set_policy(Gtk::POLICY_AUTOMATIC, Gtk::POLICY_ALWAYS)

    vbox = Gtk::VBox.new(true, 5)
    vbox.pack_start(push, false, false, 0)
    vbox.pack_start(pull, false, false, 0)


    table = Gtk::Table.new(2, 2, false)

    table.attach(scrolled_win, 0, 1, 0, 1, 
             Gtk::EXPAND | Gtk::FILL, Gtk::EXPAND | Gtk::FILL, 5, 5)
    table.attach(vbox, 1, 2, 0, 1, 
             Gtk::SHRINK, Gtk::SHRINK, 5, 5)

    window.add(table)
    window.show_all
    # Check for new messages every 50 milliseconds. This is a gross hack (it
    # would be better to trigger GUI updates when a new event is received), but
    # doing it properly (e.g., adding a new event source to the Glib main loop)
    # seems complicated.
    event_q = Queue.new
    @c.register_callback(:to_host) do
      event_q.push(true)
    end
    Gtk.timeout_add(50) do
      unless event_q.empty?
        event_q.pop
        refresh_lmap()
      end
      true
    end
  end

  def push_clicked(te)
    delta_lattice = createDelta(@textview.buffer.text, @table, @site_id)
    @lmap = @lmap.merge(delta_lattice)
    @c.send_update(@lmap)
  end

  def pull_clicked(te)
    paths = getPaths(@lmap)
    @table = createTable(@lmap, paths.reverse, 0)
    initialDoc = ""
    for key in @table.keys.sort
      initialDoc = initialDoc + @table[key][0] + '#'
    end
    initialDoc = '#' + initialDoc
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
