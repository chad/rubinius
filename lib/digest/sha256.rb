require 'digest'
require 'ext/digest/sha2/sha2'

class Digest::SHA256 < Digest::Instance

  class Context < FFI::Struct

    def self.size # HACK FFI::Struct can't do arrays
      4 * 8 + # state
      8 + # bitcount
      64 # buffer
    end

  end

  attach_function 'rbx_Digest_SHA256_Init', :sha256_init, [:pointer], :void
  attach_function 'rbx_Digest_SHA256_Update', :sha256_update,
                  [:pointer, :string, :int], :void
  attach_function 'rbx_Digest_SHA256_Finish', :sha256_finish,
                  [:pointer, :string], :void

  def initialize
    reset
  end

  def block_length
    64
  end

  def digest_length
    32
  end

  def finish
    digest = ' ' * digest_length
    self.class.sha256_finish @context.pointer, digest
    digest
  end
  alias digest! finish

  def reset
    @context.free if @context
    @context = Context.new
    self.class.sha256_init @context.pointer
  end

  def update(string)
    self.class.sha256_update @Context.pointer, string, string.length
    self
  end

  alias << update

end
