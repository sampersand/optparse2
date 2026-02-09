require 'pathname'

module OptParse2::Pathname
  OptParse2.accept Pathname do |p|
    Pathname(p)
  end
end

