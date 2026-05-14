class OptParse2
  def switch(*pos, &block)
    Builder.new(pos, block, self)
  end

  class Builder
    def initialize(positional, block, optparse2)
      @positional, @block, @optparse2 = positional, block, optparse2
      @args = {}
    end

    def build!
      @optparse2.on(*@positional, **@args, &@block)
    end

    def block(&block)
      raise LocalJumpError unless defined? yield
      @block = block
      self
    end

    def hidden(hidden = true)
      @args[:hidden] = hidden
      self
    end

    def default(value = novalue=true, description: nodescription=true, &block)
      if novalue.nil? != block.nil?
        raise ArgumentError, "Exactly one of a positional argument or a block can be given"
      end

      @args[:default] = (novalue ? block : proc { value })
      @args[:default_description] = description unless nodescription
      self
    end

    def key(key)
      @args[:key] = key
      self
    end

    def required(required = true)
      @args[:required] = required
      self
    end
  end
end

