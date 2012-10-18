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
      p "Current line id of selection"
      pp listStore.get_value(iter, 0)
    end
   
    afterButton.signal_connect( "clicked" ) do |w|

      newRow = listStore.insert_after(iter)
      oldID = listStore.get_value(iter, 0)
      if oldID == false or oldID == nil
        temp = false
      else
        temp = oldID.clone
      end
      newID = prp.getNewID(temp, 5)
      dump = PP.pp(newID, "")
      listStore.set_value(newRow, 2, dump)
      listStore.set_value(newRow, 0, newID)
      myText = entry.text
      listStore.set_value(newRow, 1, myText)
      rlm = RecursiveLmap.new(newID, myText).create()
      @lmap = @lmap.merge(rlm)
      p @lmap
      prp.printDocument(@lmap)
    end

    deleteButton.signal_connect("clicked") do |w|
      id = listStore.get_value(iter,0)
      rlm = RecursiveLmap.new(id, -1 ).create()
      @lmap = @lmap.merge(rlm)
      treeView1.model.remove(iter)
    end

    window = Gtk::Window.new("LatticeDoc")
    window.signal_connect("destroy") { Gtk.main_quit }
    window.add(vbox)
    window.show_all
    Gtk.main
  end
end


