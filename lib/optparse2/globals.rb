# frozen_string_literal: true

module OptParse2::Globals
  def self.[]=(key, value)
    key = key.to_s.gsub('-', '_')

    unless key.match? /\A[[:alpha:]_][[:alnum:]_]*\z/
      raise "invalid global name: #{key}"
    end

    eval "$#{key} = value"
  end
end
