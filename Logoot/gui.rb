#!/usr/bin/env ruby
require 'gtk2'
require './logoot_lattice'
require 'rubygems'
require './lfixed'
require 'pp'

class LatticeDocGUI

  attr_accessor :lmap
  attr_accessor :site_id

  def initialize(lmap, site_id)
    @lmap = lmap
    @site_id = site_id
  end

  def run
    prp = PrettyPrinter.new()

    listStore = Gtk::ListStore.new(Array, String, String)
    treeView1 = Gtk::TreeView.new(listStore)
    if lmap != nil
      #loadDocument(lmap, listStore, [])
    else 
      parent = listStore.append
      parent.set_value(0, [-2,-2,-2])
      parent.set_value(1, "")
    end
    firstRow = listStore.append
    treeView1.selection.mode = Gtk::SELECTION_SINGLE
    renderer = Gtk::CellRendererText.new

    col2 = Gtk::TreeViewColumn.new("Position ID", renderer, :text => 0)
    #treeView1.append_column(col2)


    col = Gtk::TreeViewColumn.new("Document", renderer, :text => 1)
    treeView1.append_column(col)
    
    col3 = Gtk::TreeViewColumn.new("Position ID", renderer, :text => 2)
    treeView1.append_column(col3)

    #beforeButton = Gtk::Button.new("Insert Before")
    afterButton = Gtk::Button.new("Insert After")
    entry = Gtk::Entry.new

    vbox = Gtk::VBox.new(homogeneous=false, spacing=nil) 
    vbox.pack_start_defaults(treeView1)
    #vbox.pack_start_defaults(beforeButton)
    vbox.pack_start_defaults(afterButton)
    vbox.pack_start_defaults(entry)

    iter = nil
    #iterPrev = nil

    treeView1.signal_connect("row-activated") do |view, path, column|
      iter = treeView1.model.get_iter(path)
      p "Current line id of selection"
      pp listStore.get_value(iter, 0)
      #iterPrev = treeView1.model.get_iter(path.prev!)
    end

    #beforeButton.signal_connect( "clicked" ) do |w|
    #  newRow = listStore.insert_before(iter)
    #  oldID = listStore.get_value(iterPrev, 0)
    #  newID = genPosIdAfter(oldID, 5)
    #  puts newID
    #  listStore.set_value(newRow, 0, newID)
    #  listStore.set_value(newRow, 1, entry.text)
    #end

    afterButton.signal_connect( "clicked" ) do |w|

      newRow = listStore.insert_after(iter)
      oldID = listStore.get_value(iter, 0)
      newID = prp.getNewID(oldID, 5)
      dump = PP.pp(newID, "")
      listStore.set_value(newRow, 2, dump)
      listStore.set_value(newRow, 0, newID)
      myText = entry.text
      listStore.set_value(newRow, 1, myText)

      rlm = RecursiveLmap.new(newID, myText).create()
      p rlm
      @lmap.merge(rlm)

    end


    window = Gtk::Window.new("LatticeDoc")
    window.signal_connect("destroy") { Gtk.main_quit }
    window.add(vbox)
    window.show_all
    Gtk.main
  end
  


  def loadDocument(lmap, treestore, posID)
    print "HERE"
    sortedKeys = lmap.reveal.keys.sort
    for key in sortedKeys
      #posID.concat([key]) unless key == [-1,-1,-1]
      if key == [-1,-1,-1]
        if lmap.reveal.values_at(key)[0].reveal != -1
          parent = treestore.append
          parent.set_value(0, [[-3,-3,-3]])
          parent.set_value(1, lmap.reveal.values_at(key)[0].reveal)
        end
        next
      end
      nextLmap = lmap.reveal[key]
      loadDocument(nextLmap, treestore, posID)
    end
  end


end

#rlm = RecursiveLmap.new([[-1,-1,-1]], "First line")
#lmap = rlm.create()
#yGui = LatticeDocGUI.new(lmap, 1)

