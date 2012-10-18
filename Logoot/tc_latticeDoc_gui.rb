require './test_common'
require 'rubygems'
require 'bud'
require './logoot_lattice'
require "set"
require './lfixed'
require './gui'

class TestRLmap < Test::Unit::TestCase
	m = RecursiveLmap.new([[0,0,0], [-1,-1,-1]], "start of document").create()
	myGUI = LatticeDocGUI.new(m, 1)
	myGUI.run
end
