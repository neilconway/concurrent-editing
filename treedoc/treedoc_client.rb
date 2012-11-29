#!/usr/bin/env ruby
require 'rubygems'
require 'backports'
require 'bud'
require 'gtk2'
require 'pp'
require_relative 'doc_protocol'
require_relative 'lfixed'
require_relative 'treeDoc_lattice'

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
  end

  def run
    @c.run_bg

    listStore = Gtk::ListStore.new(Array, String, String)
    treeView = Gtk::TreeView.new(listStore)
    treeView.selection.mode = Gtk::SELECTION_SINGLE
    renderer = Gtk::CellRendererText.new
    col0 = Gtk::TreeViewColumn.new("Position ID (Array)", renderer, :text => 0)
    col1 = Gtk::TreeViewColumn.new("Text", renderer, :text => 1)
    treeView.append_column(col1)
    col2 = Gtk::TreeViewColumn.new("Position ID", renderer, :text => 2)
    treeView.append_column(col2)

    afterButton = Gtk::Button.new("Insert After")
    beforeButton = Gtk::Button.new("Insert Before")
    deleteButton = Gtk::Button.new("Delete")
    deleteButton.sensitive = false
    entry = Gtk::Entry.new
    entry.width_chars = 30

    vbox = Gtk::VBox.new(homogeneous=false, spacing=nil)
    vbox.pack_start_defaults(treeView)
    vbox.pack_start_defaults(deleteButton)
    vbox.pack_start_defaults(afterButton)
    vbox.pack_start_defaults(beforeButton)
    vbox.pack_start_defaults(entry)

    treeView.selection.signal_connect("changed") do
      iter = treeView.selection.selected
      if iter.nil?
        deleteButton.sensitive = false
      else
        deleteButton.sensitive = true
      end
    end

    afterButton.signal_connect("clicked") do |w|
      iter = treeView.selection.selected
      if iter.nil?
        firstID = secondID = nil
      else
        firstID = listStore.get_value(iter, 0)
        raise if firstID.nil?
        iter.next!
        secondID = listStore.get_value(iter, 0)
        secondID ||= nil
      end

      puts "PRE: #{firstID.inspect}; POST = #{secondID.inspect}"
      firstID = firstID.clone if firstID
      secondID = secondID.clone if secondID
      PP.pp(firstID)
      PP.pp(secondID)

      newID = gen_id_after(firstID, @site_id)

      rlm = createDocLattice(newID, entry.text)
      @lmap = @lmap.merge(rlm)
      @c.send_update(@lmap)
      paths = getPaths(@lmap)
      myDocument = readInOrder(@lmap)
      listStore.clear
      loadDocument(@lmap, listStore, paths.sort, myDocument)
      entry.text = ""
      entry.focus = true
    end

    beforeButton.signal_connect("clicked") do |w|
      iter1 = treeView.selection.selected
      iter2 = iter_prev(iter1, treeView)
      if iter1.nil? or iter2.nil?
        firstID = secondID = nil
      else
        firstID = listStore.get_value(iter1, 0)
        firstID ||= nil
        secondID = listStore.get_value(iter2, 0)
        raise if secondID.nil?
      end

      puts "PRE: #{firstID.inspect}; POST = #{secondID.inspect}"
      firstID = firstID.clone if firstID
      secondID = secondID.clone if secondID
      newID = gen_id_before(firstID, @site_id)

      rlm = createDocLattice(newID, entry.text)
      @lmap = @lmap.merge(rlm)
      @c.send_update(@lmap)
      paths = getPaths(@lmap)
      myDocument = readInOrder(@lmap)
      listStore.clear
      loadDocument(@lmap, listStore, paths.sort, myDocument)
      entry.text = ""
      entry.focus = true
    end

    deleteButton.signal_connect("clicked") do |w|
      iter = treeView.selection.selected
      next if iter.nil?
      id = listStore.get_value(iter, 0)
      rlm = createDocLattice(id, -1)
      @lmap = @lmap.merge(rlm)
      @c.send_update(@lmap)
      paths = getPaths(@lmap)
      myDocument = readInOrder(@lmap)
      listStore.clear
      loadDocument(@lmap, listStore, paths.sort, myDocument)
    end

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
        refresh_list(listStore)
      end
      true
    end

    window = Gtk::Window.new("Lattice Editor")
    window.signal_connect("destroy") do
      @c.stop
      Gtk.main_quit
    end
    window.add(vbox)
    window.show_all
  end

  def refresh_list(listStore)
    @c.sync_do {
      @lmap = @c.m.current_value
    }
    myDocument = readInOrder(@lmap)
    listStore.clear
    paths = getPaths(@lmap)
    loadDocument(@lmap, listStore, paths.sort, myDocument)
  end

  #paths in reverse order
  def loadDocument(lmap, treestore, paths, document)
    PP.pp(paths)
    for i in 0..document.length
      if paths[i] != nil
        parent = treestore.append
        parent.set_value(0, paths[i])
        parent.set_value(1, document[i])
        parent.set_value(2, PP.pp(paths[i], ""))
      end
    end
  end
end

def readInOrder(lmap, doc=[])
  sortedKeys = lmap.reveal.keys.sort
  for key in sortedKeys
    if key == [1,1]
      if lmap.reveal.values_at(key)[0].reveal != -1
        doc << lmap.reveal.values_at(key)[0].reveal
      end
      next
    end
    readInOrder(lmap.reveal[key], doc)
  end
  return doc
end


def iter_prev(iter, treeView)
  if iter.nil?
    return nil
  end
  path = iter.path
  path.prev!
  prev_iter = treeView.model.get_iter(path)
  return prev_iter
end

if __FILE__ == $0
  server = (ARGV.length == 2) ? ARGV[1] : LatticeDocProtocol::DEFAULT_ADDR
  puts "Server address: #{server}"
  program = LatticeDocGUI.new(ARGV[0], server)
  program.run
  Gtk.main
end
