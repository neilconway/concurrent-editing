require 'rubygems'
require 'backports'
require_relative 'doc_client_paragraph'
require_relative 'doc_server'

ip, port = LatticeDocProtocol::DEFAULT_ADDR.split(":")
serv = LatticeDocServer.new(:ip => ip, :port => port.to_i)
serv.run_bg

["1", "2"].each do |client_id|
  c = LatticeDocGUI.new(client_id, LatticeDocProtocol::DEFAULT_ADDR)
  c.run
end
Gtk.main
