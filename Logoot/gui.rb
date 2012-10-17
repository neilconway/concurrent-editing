#!/usr/bin/env ruby
require 'gtk2'
require './logoot_lattice'
require 'rubygems'
require './lfixed'

class LatticeDocGUI

  #attr_accessor :lmap

  #def initialize(lmap)
    #@lamp = lmap
    rlm = RecursiveLmap.new([], "")
    lmap = rlm.create()

    listStore = Gtk::ListStore.new(Integer, String)
    treeView1 = Gtk::TreeView.new(listStore)
    if lmap != nil
      loadDocument(lmap, listStore, [])
    else 
      parent = listStore.append
      parent.set_value(0, -2)
      parent.set_value(1, "")
    end
    treeView1.selection.mode = Gtk::SELECTION_SINGLE
    renderer = Gtk::CellRendererText.new
    col2 = Gtk::TreeViewColumn.new("Position ID", renderer, :text => 0)
    treeView1.append_column(col2)
    col = Gtk::TreeViewColumn.new("Document", renderer, :text => 1)
    treeView1.append_column(col)
    

    beforeButton = Gtk::Button.new("Insert Before")
    afterButton = Gtk::Button.new("Insert After")
    entry = Gtk::Entry.new

    vbox = Gtk::VBox.new(homogeneous=false, spacing=nil) 
    vbox.pack_start_defaults(treeView1)
    vbox.pack_start_defaults(beforeButton)
    vbox.pack_start_defaults(afterButton)
    vbox.pack_start_defaults(entry)

    iter = nil

    treeView1.signal_connect("row-activated") do |view, path, column|
      iter = treeView1.model.get_iter(path)
    end

    beforeButton.signal_connect( "clicked" ) do |w|
      newRow = listStore.insert_before(iter)
      listStore.set_value(newRow, 0, 1)
      listStore.set_value(newRow, 1, entry.text)
    end

    afterButton.signal_connect( "clicked" ) do |w|
      newRow = listStore.insert_after(iter)
      listStore.set_value(newRow, 0, 5)
      listStore.set_value(newRow, 1, entry.text)
    end


    window = Gtk::Window.new("LatticeDoc")
    window.signal_connect("destroy") { Gtk.main_quit }
    window.add(vbox)
    window.show_all
    Gtk.main
  #end

  def loadDocument(lmap, treestore, posID)
    sortedKeys = lmap.reveal.keys.sort
    for key in sortedKeys
      #posID.concat([key]) unless key == [-1,-1,-1]
      if key == [-1,-1,-1]
        if lmap.reveal.values_at(key)[0].reveal != -1
          parent = treestore.append
          parent.set_value(0, -1)
          parent.set_value(1, lmap.reveal.values_at(key)[0].reveal)
        end
        next
      end
      nextLmap = lmap.reveal[key]
      loadDocument(nextLmap, treestore, posID)
    end
  end



  

end