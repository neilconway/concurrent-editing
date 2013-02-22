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
    scratch :missing_ref, insert_ops.schema
  end

  # START and END sentinels
  bootstrap do
    insert_ops <= [[START_DOC, '', nil, END_DOC],
                   [END_DOC, '', START_DOC, nil]]
  end

  bloom :check_invariants do
    stdio <~ err {|e| raise BadInvariantError, "op = #{e}" }

    # Check that pre and post refs exist
    missing_ref <= insert_ops.notin(insert_ops, :pre => :id)
    missing_ref <= insert_ops.notin(insert_ops, :post => :id)
    err <= missing_ref {|r| r unless [START_DOC, END_DOC].include? r.id}

    # Check that pre < post (redundant with acyclicity?)

    # Check that pre and post relations are acyclic

    # Check that pre/post graph is connected
  end

  def insert_op(txt, pre, post)
    insert_ops <= [[@next_op_id, txt, pre, post]]
    @next_op_id += 1
  end
end
