#!/usr/bin/env ruby
require 'rubygems'
require 'backports'
require 'bud'
require 'gtk2'
require 'pp'
require './doc_protocol'
require_relative '../nm_simple'

class Client 
	include Bud
	include DocProtocol
	#include SimpleNmLinear

	START_DOC = -1
  END_DOC = -2
  WAIT_TIME = 100

	def initialize(client_id, server, opts={})
    	@client_id = client_id
    	@server = server
    	super opts
  end

  state do
  	table :insert_ops, [:txt_id] => [:txt, :pre, :post]
    scratch :new_op, [:txt_id] => [:txt, :pre, :post] 
	end
  
  bootstrap do
    connect <~ [[@server, ip_port]]
  end

  bloom do
    stdio <~ to_host {|h| ["Message @ client #{@client_id}: #{h.inspect}"]}
    insert_ops <= to_host {|h| [h.txt_id, h.txt, h.pre, h.post]}

    to_server <~ new_op {|i| [@server, ip_port, i.txt_id, i.txt, i.pre, i.post]}
    insert_ops <= new_op {|n| [n.txt_id, n.txt, n.pre, n.post]}
  end

  def send_update(txt_id, txt, pre, post)
    puts "send_update: #{txt.inspect}"
    sync_do {
      new_op <+ [[txt_id, txt, pre, post]]
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
    @s = SimpleNmLinear.new
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
      @id_lookup_table = update_table(@id_lookup_table, it.offset, @next_id)
    	txt_id = @next_id
      @next_id = @next_id + 1
      post_id = @id_lookup_table[it.offset + 1]
      pre_id = @id_lookup_table[it.offset - 1]
      if post_id == nil
        post_id = -2
      end
      if pre_id == nil
        pre_id = -1
      end
      @client.send_update(txt_id, txt, pre_id, post_id)
      @s.input_buf <+ [[txt_id, pre_id, post_id]]
      p @s.input_buf.to_a
      p @s.before.to_a
      @s.tick
      @client.tick
      p @s.before.to_a
      @s.tick
      @client.tick
      p @s.before.to_a
      @s.tick
      @client.tick
      p @s.before.to_a

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

  def pull_clicked(ed)
    @pulled = true
    @client.sync_do {
      @s.input_buf <+ @client.insert_ops {|i| [i.txt_id, i.pre, i.post]}
    }
    100.times { |i| 
      @s.tick 
      p @s.before.inspected
    }
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