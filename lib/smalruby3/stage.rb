require_relative "sprite"

module Smalruby3
  class Stage < Sprite
    def stage?
      true
    end

    private

    def define_variable(name, value) # rubocop:disable Lint/UnusedMethodArgument
      name = "$#{name}"
      eval("#{name} = value", nil, __FILE__, __LINE__) # rubocop:disable Security/Eval
      name
    end
  end
end
