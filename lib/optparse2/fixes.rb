class OptParse2
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

  def initialize(*)
    @defaults = {}
    super
  end
end
