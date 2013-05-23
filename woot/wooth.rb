#!/usr/bin/env ruby
require 'rubygems'
require 'backports'

unless defined? Float::INFINITY
  	Float::INFINITY = 1.0/0.0
end
	
IB = -Float::INFINITY
IE = Float::INFINITY


class WootHashNode

	attr_accessor :next
	attr_accessor :visible
	attr_accessor :content
	attr_accessor :degree
	attr_accessor :id

	def initialize(id, visible, next_node, degree)
		@id = id
		@visible = visible
		@next = next_node
		@degree = degree
	end
end

class WootHashOp
	attr_accessor :post
	attr_accessor :pre
	attr_accessor :id
	attr_accessor :type

	def initialize(id, pre_id, next_id, type)
		@id = id
		@pre = pre_id
		@post = next_id
		@type = type
	end
end

class WootHashDocument

	def initialize(site_id)
		@site_id = site_id
		@size = 0
		@end = WootHashNode.new(IE, false, nil, 0)
		@first = WootHashNode.new(IB, false, @end, 0)
		@map = Hash.new
		@map[IB] = @first
		@map[IE] = @end
		@clock = 0
		@buffer = []
	end

	def buildDoc()
		curNode = @first
		doc = []
		while (curNode != nil)
			if (curNode.visible)
				doc << curNode.id
			end
			curNode = curNode.next
		end
		return doc
	end

	def check_pre_conditions(insert_op)
		if (@map[insert_op.pre] == nil)
			return false
		elsif (@map[insert_op.post] == nil)
			return false
		else
			return true
		end
	end

	def apply(op)
		if (op.type == 'del')
			del(op.id)
		elsif (op.type == 'insert')
			if check_pre_conditions(op)
				if @buffer.include?(op)
					@buffer.delete(op)
				end
				add(op.id, op.pre, op.post)
			else
				@buffer << op
			end
		end
	end

	def add(id, prevId, nextId)
		prev = @map[prevId]
		after = @map[nextId]			
		insert = WootHashNode.new(id, true, nil, [prev.degree, after.degree + 1].max)
		insert_between(insert, prev, after)
		@map[id] = insert
		@size = @size + 1
	end

	def del(id)
		to_delete = @map[id]
		to_delete.visible = false
	end

	def insert_between(to_insert, prev, after)
		if (after == prev.next)
			to_insert.next = after
			prev.next = to_insert
		else
			#Finds min degree between prev and after.
			e = prev.next.next
			min_degree = prev.next.degree
			while (e != after)
				if (e.degree < min_degree)
					min_degree = e.degree
				end
				e = e.next
			end

			e = prev.next
			while (e != after)
				if (e.degree == min_degree)
					#tie breaking.
					if (e.id < after.id)
						prev = e
					else
						after = e
					end
				end
				if (e != after)
					e = e.next
				end
			end
			insert_between(to_insert, prev, after)
		end
	end

	def trace_to_woot_op(trace)
		new_trace = []
		trace.each { |t| 
			new_trace << WootHashOp.new(t[0], t[1], t[2], 'insert')
		}
		return new_trace
	end

	def localInsert(remoteOps)
		remoteOps = trace_to_woot_op(remoteOps)
		remoteOps.each { |r|
			apply(r)
		}
		while (@buffer.size != 0)
			@buffer.each { |b|
				apply(b)
			}
		end
	end
end

