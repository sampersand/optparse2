# frozen_string_literal: true

require 'optparse'
class OptParse2 < OptParse; end # Make sure it's a subclass
OptionParser2 = OptParse2 # Alias

require_relative "optparse2/version"
require_relative "optparse2/fixes"
# require_relative "optparse2/helpers"

class OptParse2
  class << self
    attr_accessor :pos_set_banner
  end
  self.pos_set_banner = true

  def initialize(...)
    @defaults = Set[]
    @positional = []
    @required = Set[]
    @rest = nil
    self.pos_set_banner = OptParse2.pos_set_banner
    super
  end

  ## Helpers is a mixin that contains methods to modify how the original `Switch` works
  module Helpers
    def set_hidden
      def self.summarize(*) end
    end

    def switch_name=(val)
      # binding.irb
      @switch_name = val
    end

    def set_block_name_because_of_switch_name
      if @block.nil? && @arg.nil?
        q = @switch_name.to_sym
        @block = proc { q }
      end
    end

    # attr_writer :switch_name
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
      x[-1] += " [default: #{default_description}]"
      x
    end
  end

  # Update `make_switch` to support OptParse2's keyword arguments
  def make_switch(opts, block, hidden: false, key: nil, default: nodefault=true, default_description: nil,
    required: false)
    sw, *rest = super(opts, block)

    sw.extend Helpers
    if key
      sw.switch_name = key
      sw.set_block_name_because_of_switch_name
    end
    sw.set_hidden if hidden

    if (not_style = rest[2])
      not_style.extend Helpers
      not_style.switch_name = key if key
      not_style.set_hidden if hidden
    end

    if required
      unless nodefault
        raise ArgumentError, "cannot supply both a default with required: true"
      end
      @required << sw.switch_name
    end

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
      super(key, value)
      into[key] = value
    end

    non_options = []

    result = super(argv, into: already_done, **keywords, &non_options.method(:<<))

    argv2 = non_options.each_with_index.flat_map { ["--*-positional-#{_2}", _1] }

    old_raise, self.raise_unknown = self.raise_unknown, false
    begin
      super(argv2, into: already_done, **keywords)
    rescue OptParse::InvalidArgument => err
      err.args[0] = @positional[err.args[0][/\d+/].to_i].name
      raise
    ensure
      self.raise_unknown = old_raise
    end

    argv2 = argv2.each_slice(2).map { _2 }

    if @rest
      argv2 = @rest[:block].call(argv2)
      into[@rest[:key]] = argv2 if @rest[:key]
    elsif !argv.empty? && self.raise_unknown && !@positional.empty?
      raise ParseError, "got unexpected positional argument: #{argv2.inspect}"
    else
      argv2.each(&nonopt)
    end

    @defaults.each do |sw|
      key = sw.switch_name.to_sym
      next if already_done.key? key
      into[key] = sw.default()
    end

    @required.each do |key|
      raise ParseError, "required option '#{key}' not provided" unless already_done.key? key.to_sym
    end

    argv2
  end

  module Positional
    attr_accessor :name

    # Essentially directly copied from `OptParse::Switch`.summarize, except with custom `left`
    def summarize(sdone = {}, ldone = {}, width = 1, max = width - 1, indent = "")
      left = ["#{name}"]
      sdone[name] = true
      ldone[name] = true
      right = desc.dup

      mlen = left.collect {|ss| ss.length}.max.to_i
      while mlen > width and l = left.shift
        mlen = left.collect {|ss| ss.length}.max.to_i if l.length == mlen
        if l.length < width and (r = right[0]) and !r.empty?
          l = l.to_s.ljust(width) + ' ' + r
          right.shift
        end
        yield(indent + l)
      end

      while begin l = left.shift; r = right.shift; l or r end
        l = l.to_s.ljust(width) + ' ' + r if r and !r.empty?
        yield(indent + l)
      end

      self
    end

    # def match_nonswitch?(arg)
    #   p ["switch is: #{arg}"]


    #   begin
    #     opt, cb, val = parse(arg, []) {|*exc| raise(*exc)}
    #     val = $op.send :callback!, cb, 1, val if cb
    #     $op.send :callback!, $setter, 2, switch_name, val if $setter
    #   rescue OptParse::ParseError
    #     raise $!.set_option(arg, rest)
    #   end
    #   p "ok!"
    #   throw :prune

    #   # p arg
    # end

    # def parse(*argv, **keywords)
    #   p argv, keywords
    #   # p [argv, keywords]
    #   # exit 1
    # end
  end

  attr_accessor :pos_set_banner
  def pos(name, *a, key: name, **b, &block)
    banner.concat " #{name}" if pos_set_banner

    sw, *rest = make_switch ["--*-positional-#{@positional.length} #{name}", *a], block, key:, **b
    sw.extend Positional
    sw.name = name
    sw.switch_name = key
    top.append(sw, *rest)
    @positional.append sw
  end

  def rest(name, description, &block)
    @rest = { key: name.to_sym, block: }
  end
end

__END__
return unless $0 == __FILE__
require_relative 'optparse2/pathname'

# $* << '-tFOO' << '--no-cache' << '-x'
# $*.replace %w[123 lol what -t10 is up here]
$*.replace %w[--timeout=a a]

OPTS={}
OptParse2.new do |op|
  $op = op
  op.on '-t', '--timeout=FOO', Array,required: true
  op.pos 'file', Integer, 'sets the file name', 'is also pretty cool', 1..1000, required: true do it * 2 end
  op.pos '[start[-end]]', 'things to do', key: 'line', default: 123

  # op.rest 'message', 'Message to submit' do it.join ' ' end
  op.parse! into: OPTS
  p ["finish: ", OPTS, $*]
end
