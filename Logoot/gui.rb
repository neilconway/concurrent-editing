#!/usr/bin/env ruby
require 'gtk2'
require './logoot_lattice'
require 'rubygems'
require './lfixed'
require 'pp'
require './latticeDocProtocol'

class Client 
  include Bud
  include LatticeDocProtocol
  
  def initialize(server,opts={})
    @server = server
    super opts
  end

  state do
    lmap :m
  end

  bootstrap do
    connect <~ [[@server, [ip_port]]]
  end

  bloom do 
    toServer <~ [[@server, ip_port, m]]
    m <= toHost.payloads
  end
end


class LatticeDocGUI
  include Bud

  attr_accessor :lmap
  attr_accessor :site_id

  def initialize(site_id, server)
    @lmap = RecursiveLmap.new([[-1,-1,-1]], "begin document").create()
    @site_id = site_id
    @server = server
  end

  def run
    p @server
    p @site_id
    c = Client.new(@server)
    #c.m <+ @lmap
    c.tick

    prp = PrettyPrinter.new()

    listStore = Gtk::ListStore.new(Array, String, String)
    treeView1 = Gtk::TreeView.new(listStore)
    firstRow = listStore.append
    treeView1.selection.mode = Gtk::SELECTION_SINGLE
    renderer = Gtk::CellRendererText.new
    col2 = Gtk::TreeViewColumn.new("Position ID", renderer, :text => 0)
    col = Gtk::TreeViewColumn.new("Document", renderer, :text => 1)
    treeView1.append_column(col)
    col3 = Gtk::TreeViewColumn.new("Position ID- String", renderer, :text => 2)
    treeView1.append_column(col3)


    afterButton = Gtk::Button.new("Insert After")
    deleteButton = Gtk::Button.new("Delete")
    entry = Gtk::Entry.new

    vbox = Gtk::VBox.new(homogeneous=false, spacing=nil) 
    vbox.pack_start_defaults(treeView1)
    vbox.pack_start_defaults(deleteButton)
    vbox.pack_start_defaults(afterButton)
    vbox.pack_start_defaults(entry)

    iter = nil

    treeView1.signal_connect("row-activated") do |view, path, column|
      iter = treeView1.model.get_iter(path)
      p "Selected"
    end
   
    afterButton.signal_connect( "clicked" ) do |w|

      newRow = listStore.insert_after(iter)
      oldID = listStore.get_value(iter, 0)
      if oldID == false or oldID == nil
        temp = false
      else
        temp = oldID.clone
      end
      newID = prp.getNewID(temp, Integer(@site_id))
      dump = PP.pp(newID, "")
      listStore.set_value(newRow, 2, dump)
      listStore.set_value(newRow, 0, newID)
      myText = entry.text
      listStore.set_value(newRow, 1, myText)
      
      rlm = RecursiveLmap.new(newID, myText).create()
      @lmap = @lmap.merge(rlm)
      c.m <+ @lmap
      c.tick
      @lmap = c.m.current_value
      listStore.clear
      paths = prp.getPaths(@lmap)
      for x in paths
        x << [-1,-1,-1]
      end
      loadDocument(c.m.current_value, listStore, paths.reverse)
    end

    deleteButton.signal_connect("clicked") do |w|
      id = listStore.get_value(iter,0)
      rlm = RecursiveLmap.new(id, -1 ).create()
      @lmap = @lmap.merge(rlm)
      c.m <+ @lmap
      c.tick
      treeView1.model.remove(iter)
      @lmap = c.m.current_value
      listStore.clear
      paths = prp.getPaths(@lmap)
      for x in paths
        x << [-1,-1,-1]
      end
      loadDocument(c.m.current_value, listStore, paths.reverse)
    end

    window = Gtk::Window.new("LatticeDoc")
    window.signal_connect("destroy") { Gtk.main_quit }
    window.add(vbox)
    window.show_all
    Gtk.main
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


server = (ARGV.length == 2) ? ARGV[1] : "localhost:12345"
puts "Server address: #{server}"
program = LatticeDocGUI.new(ARGV[0], server)
program.run

