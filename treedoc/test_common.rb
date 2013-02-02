require 'rubygems'
require 'bud'

gem 'minitest'  # Use the rubygems version of MT, not builtin (if on 1.9)
require 'minitest/autorun'

$:.unshift File.join(File.dirname(__FILE__), "..")
