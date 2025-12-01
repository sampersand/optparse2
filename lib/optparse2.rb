# frozen_string_literal: true

require_relative "optparse2/version"

class OptParse2 < OptParse
  # Provide support for passing keyword arguments into `make_switch`
  def define(*opts, **, &block) top.append(*(sw = make_switch(opts, block, **))); sw[0] end
  alias def_option define
  def on(...) define(...); self end

  def define_head(*opts, **, &block) top.prepend(*(sw = make_switch(opts, block, **))); sw[0] end
  alias def_head_option define_head
  def on_head(...) define_head(...); self end

  def define_head(*opts, **, &block) base.append(*(sw = make_switch(opts, block, **))); sw[0] end
  alias def_tail_option define_tail
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

  # def env(var, *opts, hidden: false, &)
  #   fail if hidden
  #   sw, = make_switch(['-_X', *opts])

  #   p sw
  #   exit
  #   on_tail(var)
  # end

  # def positional
end
