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
    @lmap = createDocLattice([[-1,-1,-1]], "begin document")
  end

  def run
    c = Client.new(@site_id, @server)
    c.run_bg

    listStore = Gtk::ListStore.new(Array, String, String)
    treeView1 = Gtk::TreeView.new(listStore)
    treeView1.selection.mode = Gtk::SELECTION_SINGLE
    renderer = Gtk::CellRendererText.new
    col0 = Gtk::TreeViewColumn.new("Position ID (Array)", renderer, :text => 0)
    col1 = Gtk::TreeViewColumn.new("Text", renderer, :text => 1)
    treeView1.append_column(col1)
    col2 = Gtk::TreeViewColumn.new("Position ID", renderer, :text => 2)
    treeView1.append_column(col2)

    afterButton = Gtk::Button.new("Insert After")
    deleteButton = Gtk::Button.new("Delete")
    refreshButton = Gtk::Button.new("Refresh")
    entry = Gtk::Entry.new

    vbox = Gtk::VBox.new(homogeneous=false, spacing=nil)
    vbox.pack_start_defaults(treeView1)
    vbox.pack_start_defaults(deleteButton)
    vbox.pack_start_defaults(afterButton)
    vbox.pack_start_defaults(refreshButton)
    vbox.pack_start_defaults(entry)

    iter = nil

    treeView1.signal_connect("row-activated") do |view, path, column|
      iter = treeView1.model.get_iter(path)
      puts "Selected: #{path.to_s}"
    end

    afterButton.signal_connect("clicked") do |w|
      puts "afterButton clicked!"
      firstID = listStore.get_value(iter, 0) unless iter.nil?
      if firstID == false or firstID == nil
        temp = false
      else
        temp = firstID.clone
      end
      if iter == nil
        newID = getNewID(temp, @site_id)
      else
        iter.next!
        secondID = listStore.get_value(iter, 0)
        if secondID == false or secondID == nil
          temp2 = false
        else
          temp2 = secondID.clone
        end
        newID = generateNewId(temp, temp2, @site_id)
      end
      puts "got here!"
      rlm = createDocLattice(newID, entry.text)
      @lmap = @lmap.merge(rlm)
      c.send_update(@lmap)
      paths = getPaths(@lmap)
      for x in paths
        x << [-1,-1,-1]
      end
      listStore.clear
      loadDocument(@lmap, listStore, paths.reverse)
      entry.text = ""
      entry.focus = true
    end

    deleteButton.signal_connect("clicked") do |w|
      id = listStore.get_value(iter, 0)
      rlm = createDocLattice(id, -1)
      @lmap = @lmap.merge(rlm)
      c.send_update(@lmap)
      treeView1.model.remove(iter)
      paths = getPaths(@lmap)
      for x in paths
        x << [-1,-1,-1]
      end
      listStore.clear
      loadDocument(@lmap, listStore, paths.reverse)
    end

    refreshButton.signal_connect("clicked") do |w|
      c.sync_do {
        @lmap = c.m.current_value
      }
      listStore.clear
      paths = getPaths(@lmap)
      for x in paths
        x << [-1,-1,-1]
      end
      loadDocument(@lmap, listStore, paths.reverse)
    end

    window = Gtk::Window.new("LatticeDoc")
    window.signal_connect("destroy") do
      c.stop
      Gtk.main_quit
    end
    window.add(vbox)
    window.show_all
  end

  #paths in reverse order
  def loadDocument(lmap, treestore, paths)
    sortedKeys = lmap.reveal.keys.sort
    for key in sortedKeys
      if key == [-1,-1,-1]
        if lmap.reveal.values_at(key)[0].reveal != -1
          parent = treestore.append
          curPath = paths.pop
          parent.set_value(0, curPath)
          parent.set_value(1, lmap.reveal.values_at(key)[0].reveal)
          parent.set_value(2, PP.pp(curPath, ""))
        end
        next
      end
      nextLmap = lmap.reveal[key]
      loadDocument(nextLmap, treestore, paths)
    end
  end
end

if __FILE__ == $0
  server = (ARGV.length == 2) ? ARGV[1] : LatticeDocProtocol::DEFAULT_ADDR
  puts "Server address: #{server}"
  program = LatticeDocGUI.new(ARGV[0], server)
  program.run
  Gtk.main
end