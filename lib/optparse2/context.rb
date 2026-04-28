class OptParse2
  # A Context is in charge of all option parsing
  class Context
    class << self
      attr_accessor :current

      def with_context(...)
        context = new(...)
        old, self.current = current, context
        yield context
      ensure
        self.current = old
      end
    end

    attr_reader :non_options, :deferred_options, :already_parsed_options

    def initialize(into:, nonopt:)
      @into = into
      @nonopt = nonopt

      @already_parsed_options = {}
      @non_options = []
      @deferred_options = {}
    end

    def add_non_option(non_option)
      @non_options << non_option
    end

    def handle_deferred!
      @deferred_options.each do |key, deferred|
        self[key] = deferred[:proc].call(deferred[:data]) if deferred[:proc]
      end
    end

    def key?(key)
      @already_parsed_options.key?(key)
    end

    # Directly assigns `value` to `key`, both in the internal list of parsed
    # options, as well as in the `into:` option (if one is provided).
    #
    # Note that if `value` is `DONT_ASSIGN` nothing happens
    def []=(key, value)
      return if DONT_ASSIGN.equal?(value)
      @already_parsed_options[key] = value
      @into[key] = value if @into
    end
  end
end
