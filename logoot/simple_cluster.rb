require 'rubygems'
require 'backports'
require_relative 'doc_client'
require_relative 'doc_server'

ip, port = LatticeDocProtocol::DEFAULT_ADDR.split(":")
serv = LatticeDocServer.new(:ip => ip, :port => port.to_i)
serv.run_bg

c1 = LatticeDocGUI.new("1", LatticeDocProtocol::DEFAULT_ADDR)
c2 = LatticeDocGUI.new("2", LatticeDocProtocol::DEFAULT_ADDR)
c1.run
c2.run
Gtk.main
