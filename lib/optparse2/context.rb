class OptParse2
  class << self
    attr_accessor :current_context

    def with_context(context)
      old, self.current_context = current_context, context
      yield context
    ensure
      self.current_context = old
    end
  end

  class Context
    def initialize(into:, nonopt:)
      @into = into
      @nonopt = nonopt

      @already_parsed_options = {}
      @non_options = []
    end

    attr_reader :non_options

    def add_non_option(non_option)
      @non_options << non_option
    end

    def []=(key, value)
      @already_parsed_options[key] = value
      @into[key] = value
    end
  end
end
