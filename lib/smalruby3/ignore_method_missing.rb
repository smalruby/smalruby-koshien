module Smalruby3
  class IgnoreMethodMissing
    def method_missing(name, *args)
      warn "no method error: `name'"
      self.class.new
    end

    def respond_to_missing?(sym, include_private)
      super
    end
  end
end
