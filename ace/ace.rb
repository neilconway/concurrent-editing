require 'rubygems'
require 'bud'
require_relative 'lseq'

class BadInvariantError < StandardError; end

class AceReplica
  include Bud

  START_DOC = -1
  END_DOC = -2

  def initialize
    super
    @next_op_id = 0
  end

  state do
    table :insert_ops, [:id] => [:txt, :pre, :post]
    scratch :err, insert_ops.schema
  end

  # START and END sentinels
  bootstrap do
    insert_ops <= [[START_DOC, '', nil, END_DOC],
                   [END_DOC, '', START_DOC, nil]]
  end

  bloom :check_invariants do
    stdio <~ err {|e| raise BadInvariantError, "op = #{e}" }

    # Check that pre reference exists
    err <= (insert_ops * insert_ops).outer(:pre => :id) do |i, pad|
      if i.pre != pad.id
        i unless [START_DOC, END_DOC].include? i.id
      end
    end

    # Check that post reference exists
    err <= (insert_ops * insert_ops).outer(:post => :id) do |i, pad|
      if i.post != pad.id
        i unless [START_DOC, END_DOC].include? i.id
      end
    end

    # Check that pre < post

    # Check that pre and post relations are acyclic
  end

  def insert_op(txt, pre, post)
    insert_ops <= [[@next_op_id, txt, pre, post]]
    @next_op_id += 1
  end
end
