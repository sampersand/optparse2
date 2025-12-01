# frozen_string_literal: true

require 'optparse'
class OptParse2 < OptParse; end # Make sure it's a subclass
OptionParser2 = OptParse2 # Alias

require_relative "optparse2/version"

class OptParse2
  # Provide support for passing keyword arguments into `make_switch`, until https://github.com/ruby/optparse/pull/121 is merged
  def define(*opts, **, &block) top.append(*(sw = make_switch(opts, block, **))); sw[0] end
  def define_head(*opts, **, &block) top.prepend(*(sw = make_switch(opts, block, **))); sw[0] end
  def define_head(*opts, **, &block) base.append(*(sw = make_switch(opts, block, **))); sw[0] end
  alias def_option define
  alias def_head_option define_head
  alias def_tail_option define_tail
  def on(...) define(...); self end
  def on_head(...) define_head(...); self end
  def on_tail(...) define_tail(...); self end

  # Update `make_switch` to support OptParse2's keyword arguments
  def make_switch(opts, block, hidden: false, key: nil)
    sw, *rest = super(opts, block)

    key and sw.define_singleton_method(:switch_name) { key }
    hidden and def sw.summarize(*) end

    [sw, *rest]
  end

  # Provide a "summary" field, which just puts the message at the end of the usage
  def summary(msg)
    on_tail("\n" + msg)
  end
end
