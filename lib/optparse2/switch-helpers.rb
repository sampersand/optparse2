class OptParse2
  ## Helpers is a mixin that contains methods to modify how the original `Switch` works

  module Helpers
    # Mark the switch as hidden (so it won't show up in the usage)
    def set_hidden
      def self.summarize(*) end
    end

    # The name of the switch; this is the key that's used when assigning options into an `into:`.
    # It normally corresponds to the flag name (`--foo-bar` -> `foo-bar`), but can be overwritten
    # as needed.
    attr_writer :switch_name
    def switch_name
      defined?(@switch_name) ? @switch_name : super
    end

    # Same as `switch_name`, except it also will set the block to just return the original switch
    # name as a symbol. Useful for group switches which don't actually have blocks:
    #    op.on '--interactive', key: :mode
    #    op.on '--force', key: :mode
    # instead of:
    #    op.on '--interactive', key: :mode do :interactive end
    #    op.on '--force', key: :mode do :force end
    # without this method, passing `--interactive` would just set `:mode` to `true`.
    #
    # This only happens if no block exists, and the argument does not take an arg.
    def set_switch_name_possibly_block_value(val)
      if @block.nil? && @arg.nil?
        old_switch_name = switch_name.to_sym
        @block = proc { old_switch_name }
      end

      self.switch_name = val
    end

    # Default values of switches are used when the switch is never passed in.
    # If the `value` that's provided doesn't respond to `.call`, it's converted to a proc.
    # If `bypass` is truthy, then the default value is never passed to the block's proc (if any)
    def set_default(value, description, bypass)
      if @arg.nil? && value != true && !bypass
        raise ArgumentError, "Cannot supply a non-true default value to a flag which takes no arguments", caller(4)
      end

      if defined? value.call
        @default_proc = value
      else
        @default_proc = proc { |_switch_name| value }
      end

      @default_description = description
      @default_bypass = bypass
    end

    # Calls the default proc to figure out what the default value is for this switch
    def default_bypass? = @default_bypass
    def default? = defined?(@default_proc)
    def default = @default_proc&.call(switch_name)

    def default_description = @default_description || default.inspect
    def desc
      return super unless defined? @default
      x = super
      x << '' if x.empty?
      x[-1] += " [default: #{default_description}]"
      x
    end
  end
end
