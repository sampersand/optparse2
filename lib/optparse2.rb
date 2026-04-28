# frozen_string_literal: true

require 'optparse'
class OptParse2 < OptParse; end # Make sure it's a subclass
OptionParser2 = OptParse2 # Alias

require_relative "optparse2/version"
require_relative "optparse2/fixes"
require_relative "optparse2/switch-helpers"
require_relative "optparse2/context"

class OptParse2
  class << self
    attr_accessor :pos_set_banner
  end
  self.pos_set_banner = true

  def initialize(...)
    @defaults = Set[]
    @positional = []
    @rest = nil
    @group = nil
    self.pos_set_banner = OptParse2.pos_set_banner
    super
  end

  # A constant that, when returned, will not actually assign objects inside `into:`s.
  DONT_ASSIGN = Object.new.freeze

  # Update `make_switch` to support OptParse2's keyword arguments
  def make_switch(
    opts,
    block,
    hidden: false,
    key: @group,
    default: nodefault=true,
    default_bypass: false,
    default_description: nil,
    required: false,
    multiple: nil
  )
    sw, *rest = super(opts, block)

    sw.extend Helpers
    if key
      sw.set_switch_name_possibly_block_value key
    end
    sw.set_hidden if hidden
    sw.set_multiple multiple if multiple

    if (not_style = rest[2])
      not_style.extend Helpers
      not_style.switch_name = key if key
      not_style.set_hidden if hidden
    end

    sw.set_required true if required

    if nodefault && default_description != nil
      raise ArgumentError, "default: not supplied, but default_description: given"
    elsif nodefault && default_bypass
      raise ArgumentError, "default: not supplied, but default_bypass: given"
    elsif not nodefault
      sw.set_default(default, default_description, default_bypass)
      @defaults << sw
    end

    [sw, *rest]
  end

  # Provide a "summary" field, which just puts the message at the end of the usage
  def summary(msg)
    on_tail("\n" + msg)
  end

  def group(name, default: nodefault=true)
    old_group, @group = @group, name
    yield
    if !nodefault && !@defaults.any? { |x| x.switch_name.to_sym == name }
      (orig_default = default; default = proc { orig_default }) unless default.respond_to?(:call)
      @defaults << Struct.new(:switch_name, :default_){ def default = default_.() }.new(name, default) # TODO: This should probably be extracted out into a class lol
    end
  ensure
    @group = old_group
  end

  alias _super_order! order!

  # Parses all positional arguments from `argv` into `into`. Replaces `argv` with non-positional
  # arguments when it's done.
  private def parse_positional_arguments!(argv, context, keywords)
    return if argv.empty? || @positional.empty?

    # Prepend argument number to the argument array
    argv.replace argv.each_with_index.flat_map { |value, idx| ["--*-positional-#{idx}", value] }

    # Fetch all positional arguments using the same option parsing code
    old_raise, self.raise_unknown = self.raise_unknown, false
    begin
      _super_order!(argv, into: context, **keywords)
    rescue OptParse::InvalidArgument => err
      err.args[0] = @positional[err.args[0][/\d+/].to_i].name
      raise
    ensure
      self.raise_unknown = old_raise
    end

    # Delete any non-matching arguments. TODO: Can this be the return value of `_super_order!` ?
    argv.replace argv.each_slice(2).map { |_flag_name, value| value }
  end

  # If a "rest" parameter was given, populates it. Also raises a ParseError exception for unexepcted
  # positionals if no `.rest` parameter is present, `self.raise_unknown` is set, and at least one `.pos`
  # positional argument was supplied
  private def parse_rest_argument!(argv, context)
    if @rest
      if argv.length < @rest.fetch(:required, 0)
        raise ParseError, "at least #{@rest[:required]} trailing arguments required (only got #{argv.length})", caller(1)
      end

      argv = @rest[:block] ? @rest[:block].call(argv) : argv
      context[@rest[:key]] = argv.dup if @rest[:key]
      argv.clear
    elsif !argv.empty? && self.raise_unknown && !@positional.empty?
      raise ParseError, "got unexpected positional argument: #{argv.first}", caller(1)
    end
  end

  # Goes thru every default option, and calls
  private def assign_defaults!(context)
    visit :each_option do |sw|
      next if !sw.default? || context.key?(key = sw.switch_name.to_sym)

      if sw.default_bypass?
        context[key] = sw.default
      else
        flag = sw.short.first || sw.long.first || raise("<INTERNAL ERROR: CAN THIS EVER HAPPEN?>")
        _super_order! [flag, sw.default], into: context
      end
    end
  end

  private def ensure_all_required_arguments_were_supplied!(context)
    visit :each_option do |sw|
      next unless sw.required?
      key = sw.switch_name.to_sym
      raise ParseError, "required option '#{key}' not provided" unless context.key? key
    end
  end

  def order!(argv = default_argv, into: nil, abort: false, **keywords, &nonopt)
    Context.with_context into:, nonopt: do |context|

      # Parse all normal options in the command line
      non_options = []
      trailing_options = super(argv, into: context, **keywords, &non_options.method(:<<))
      not_matched_options = non_options + trailing_options

      # Now parse positional arguments and the "rest" argument
      parse_positional_arguments!(not_matched_options, context, keywords)
      parse_rest_argument!(not_matched_options, context)

      context.handle_deferred!

      # Now handle defaults---anything with a default that hasn't been assigned so far is set
      assign_defaults!(context)

      # Now that all arguments are parsed, and the defaults have been handled, check to make sure
      # that all required arguments are handled.
      ensure_all_required_arguments_were_supplied!(context)

      # For each non-option argument, call the `nonopt` block
      not_matched_options.each(&nonopt)

      # Replace the original argv with the resulting options
      argv.replace not_matched_options
    end
  rescue OptionParser::ParseError => err
    abort ? abort(err) : raise
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
    if pos_set_banner
      banner.concat " #{b[:required] ? '' : '['}#{name}#{b[:required] ? '' : ']'}"
    end

    sw, *rest = make_switch ["--*-positional-#{@positional.length} #{name}", *a], block, key:, **b
    sw.extend Positional
    sw.name = name
    sw.switch_name = key
    top.append(sw, *rest)
    @positional.append sw
  end

  def rest(name, *description, key: name.to_s.tr(' ', '-').to_sym, required: 0, &block)
    required = case required
               when true then 1
               when false then 0
               when ->x{ Integer === x && !x.negative? } then required
               else raise TypeError, "invalid type for required: #{required.class} (must be bool or positive integer)"
               end

    required = 1 if required == true
    title = "#{'[' if required.zero?}#{name} ...#{']' if required.zero?}"
    banner.concat " #{title}" if pos_set_banner
    title += " (#{required} arg minimum)" if required > 0

    on sprintf "%s%-*s %s", summary_indent, summary_width, title, description.first
    description[1..]&.each do |descr|
      on sprintf "%s%-*s %s", summary_indent, summary_width, '', descr
    end

    @rest = { name:, key:, required: required || 0, block: }
  end
end

__END__
OptParse2.new do |op|
  op.on '--foo=FOO', multiple: :first! do puts "FOO: #{it}"; it end
  op.on '--bar=BAR'                   do puts "BAR: #{it}"; it end

  op.on '-v', '--verbose[=X]', Integer, multiple: :count

  # op.on '-v', '--verbose[=X]', Integer, multiple: :count! do
  #   puts "verbose is: #{it}"
  #   it
  # end

  op.on '-aF', Integer, multiple: [:collect, :succ.to_proc] do |x|
    p x
  end

  op.parse! %w[ -vvv -q --foo=abc --bar=123 --foo=xyz -a3 -a4 -a5 ], into: opts={}
  p opts
end

# OptParse.new do |op|
#   op.on '--foo=bar', /(.)(.)/ do |x| p x end
#     op.parse! %w[ --foo=34 ]
# end
__END__
OptionParser2.new do |op|
  op.on '-e', default: true
  op.on '--bar1=ALL', default: 'hello', &:upcase
  op.on '--doit=WHAT', /(.)(.)/, key: :A, default: 'xu' do
    p [_1, _2, 'both!']
  end

  op.pos 'foo', required: true do 3 end
  op.pos 'bar', required: true
  op.pos 'baz', required: false
  op.pos 'quux', required: false
  # op.rest 'files'


  rest = op.order!(argv = %w[ --doit 3q a b ] , into: opts={})

  puts "rest=#{rest}"
  puts "argv=#{argv}"
  puts "opts=#{opts}"
end
