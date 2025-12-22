# frozen_string_literal: true

require 'optparse'
class OptParse2 < OptParse; end # Make sure it's a subclass
OptionParser2 = OptParse2 # Alias

require_relative "optparse2/version"
require_relative "optparse2/fixes"
# require_relative "optparse2/helpers"

class OptParse2
  def initialize(...)
    @defaults = {}
    super
  end

  ## Helpers is a mixin that contains methods to modify how the original `Switch` works
  module Helpers
    def set_hidden
      def self.summarize(*) end
    end

    attr_writer :switch_name
    def switch_name; defined?(@switch_name) ? @switch_name : super end


    # requires `switch_name`, `desc` to work
    def set_default(value, description)
      if defined? value.call
        @default = value
      else
        @default = proc { value }
      end

      @default_description = description
    end

    def default = @default.call(switch_name)
    def default_description = @default_description || default.inspect
    def desc
      return super unless defined? @default
      x = super
      x << '' if x.empty?
      x.last << " [default: #{default_description}]"
      x
    end
  end

  # Update `make_switch` to support OptParse2's keyword arguments
  def make_switch(opts, block, hidden: false, key: nil, default: nodefault=true, default_description: nil)
    sw, *rest = super(opts, block)

    sw.extend Helpers

    sw.switch_name = key if key
    sw.set_hidden if hidden

    if nodefault && default_description != nil
      raise ArgumentError, "default: not supplied, but default_description: given"
    elsif not nodefault
      sw.set_default(default, default_description)
    end

    [sw, *rest]
  end

  # Provide a "summary" field, which just puts the message at the end of the usage
  def summary(msg)
    on_tail("\n" + msg)
  end

  def order!(argv = default_argv, into: nil, **keywords, &nonopt)
    if into.nil? && !@defaults.empty?
      raise "cannot call `order!` without an `into:` if there are default values"
    end

    already_done = {}
    already_done.define_singleton_method(:[]=) do |key, value|
      key = key.to_s
      super(key, value)
      into[key] = value
    end

    result = super(argv, into: already_done, **keywords, &nonopt)

    @defaults.each do |key, value|
      next if already_done.key? key
      into[key] = value.()
    end

    result
  end
end
