# frozen_string_literal: true

require 'optparse'
class OptParse2 < OptParse; end # Make sure it's a subclass
OptionParser2 = OptParse2 # Alias

require_relative "optparse2/version"
require_relative "optparse2/fixes"

class OptParse2
  def initialize(...)
    @defaults = Set[]
    @positionals = []
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

    def default = @default&.call(switch_name)
    def default_description = @default_description || default.inspect
    def desc
      return super unless @default && default_description
      x = super
      x << '' if x.empty?
      (x[-1] = +x[-1]) << " [default: #{default_description}]"
      def self.default_description = nil
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
      @defaults << sw
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

    retrieved_args = []
    result = super(argv, into: already_done, **keywords, &retrieved_args.method(:<<))

    @positionals.each do |x|
      x => {name:, sw:, required:}
      break
      if retrieved_args.empty?
        if required
          raise ParseError, "missing required argument: #{name}"
        end

        next
      end

      value = retrieved_args.shift
      value = block.call value if block
      already_done[key] = value
    end

    retrieved_args.each do |arg|
      nonopt.call arg
    end

    # p argv

    @defaults.each do |sw|
      key = sw.switch_name
      next if already_done.key? key
      into[key] = sw.default()
    end

    result
  end

  # For now, only supports strings for description, unlike other things which also support class and whatnot.
  def positional(name, *description, key: name, required: true, &block)
    # on sprintf "%s%-*s %s", summary_indent, summary_width, (x = required ? name : "[#{name}]"), description.shift
    # banner.concat " #{x}"
    # description.each do |descr|
    #   on "#{summary_indent}#{' ' * summary_width} #{descr}"
    # end

    sw, * = make_switch(['-_'] + description, block)
    sw.instance_variable_set(:@short, ["[#{name}]"])
    p sw.switch_name
    # sw.insshort = [ "[file]" ]
    top.append(sw, [], [], nil, [])
    @positionals << { name:, required:, sw: }
  end
end

require 'optparse/date'
OptParse2.new do |op|
  op.program_name.sub! '-', ' '
  op.banner = "usage: #{op.program_name} [options] [--] [branch name to be joined by hyphens]"

  DEFAULT_PREFIX = ENV['SampShell_git_branch_prefix'] || ENV.fetch('LOGNAME')
  # DEFAULT_PREFIX = ENV.fetch('SampShell_git_branch_prefix')
  #   op.env('SampShell_git_branch_prefix', 'Default prefix for -p',
  #          unset: :empty, default: proc{ ENV.fetch('LOGNAME') })

  DEFAULT_SEP = ENV['SampShell_git_separator'] || '/'

  # DEFAULT_SEP =
  #   op.env('SampShell_git_separator', 'Default separator', default: '/')

  op.on '-d', '--date=DATE', Date, 'Set the date',
    default: proc{ Date.today }, default_description: 'today'

  op.on '-p', '--prefix=PREFIX', 'Set branch prefix',
    default: DEFAULT_PREFIX, default_description: 'current user'

  op.on '-s', '--sep=SEP', 'Sets the separator',
    default: DEFAULT_SEP

  op.positional 'file', Integer, 'File to use', 'isnt it cool', required: true do |x|
    x
  end

  # op.positional 1.., 'Branch name (to be joined by `-`)' do |args|
  #   args.join('-')
  # end
  op.summary_width = 100

  op.parse! into: x={}#OptParse2::Globals
  p x
  puts op.help
end
BEGIN{ $* << '-file' << '123' }

