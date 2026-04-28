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

    def set_multiple(multiple)
      old_block = @block
      sw = switch_name.to_sym

      case multiple
      in :first!
        @block = ->(arg, **nil) do
          ctx = OptParse2::Context.current
          if ctx.deferred_options.key? sw
            OptParse2::DONT_ASSIGN
          else
            ctx.deferred_options[sw] = {}
            old_block ? old_block.call(arg) : arg
          end
        end
      in :first
        @block = ->(arg, **nil) do
          ctx = OptParse2::Context.current
          if ctx.deferred_options.key? sw
            OptParse2::DONT_ASSIGN
          else
            ctx.deferred_options[sw] = {
              proc: old_block ? proc{ old_block.call(arg) } : proc { arg }
            }
            OptParse2::DONT_ASSIGN
          end
        end
      in :last!, nil
        # don't do anything, this is the default behaviour
      in :last
        @block = ->(arg, **nil) do
          ctx = OptParse2::Context.current
          ctx.deferred_options[sw] = {
            proc: old_block ? proc { old_block.call(arg) } : proc { arg }
          }

          OptParse2::DONT_ASSIGN
        end
      in :raise
        @block = ->(arg) do
          ctx = OptParse2::Context.current
          if ctx.already_parsed_options.key? sw or ctx.deferred_options.key? sw
            raise OptParse2::ParseError, "encountered repeated option"
          end

          old_block ? old_block.call(arg) : arg
        end

      in :count
        @block = ->(amnt, **nil) do
          ctx = OptParse2::Context.current

          ctx.deferred_options[sw] ||= {
            proc: old_block ? proc { |data| old_block.call(data) } : proc { |data| data },
            data: 0
          }

          if amnt == true || amnt.nil?
            ctx.deferred_options[sw][:data] += 1
          else
            ctx.deferred_options[sw][:data] = amnt
          end

          OptParse2::DONT_ASSIGN
        end

      in :count!
        @block = ->(amnt, *a, **k, &b) do
          ctx = OptParse2::Context.current

          ctx.deferred_options[sw] ||= { data: 0 }

          if amnt == true || amnt.nil?
            ctx.deferred_options[sw][:data] += 1
          else
            ctx.deferred_options[sw][:data] = amnt
          end

          new_amnt = old_block ? old_block.call(ctx.deferred_options[sw][:data], *a, **k, &b) : ctx.deferred_options[sw][:data]
          ctx.deferred_options[sw][:data] = new_amnt unless OptParse2::DONT_ASSIGN.equal? new_amnt

          new_amnt
        end

      in :collect | [:collect, _]
        transform = Array(multiple)[1]
        @block = ->(arg, **nil) do
          ctx = OptParse2::Context.current
          ctx.deferred_options[sw] ||= {
            proc: proc { |data| old_block ? old_block.call(data) : data },
            data: []
          }

          ctx.deferred_options[sw][:data] << (transform ? transform.(arg) : arg)
          OptParse2::DONT_ASSIGN
        end

      else
        raise ArgumentError, "invalid multiple type: #{multiple}", caller(2)
      end
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
      return super unless defined? @default_proc
      x = super
      x << '' if x.empty?
      x[-1] += " [default: #{default_description}]"
      x
    end
  end
end
