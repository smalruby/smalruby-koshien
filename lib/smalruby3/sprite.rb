require_relative "world"
require_relative "list"
require_relative "ignore_method_missing"
require_relative "koshien"

module Smalruby3
  class Sprite
    attr_accessor :name
    attr_reader :variables
    attr_reader :lists

    def initialize(name, options = {}, &block)
      @name = name
      @variables = []
      @lists = []

      self.variables = options[:variables] if options[:variables]
      self.lists = options[:lists] if options[:lists]

      World.instance.add_target(self)

      instance_eval(&block) if block
    end

    def stage?
      false
    end

    def variables=(attrs)
      @variables = attrs.map { |attr|
        define_variable(attr[:name], attr.key?(:value) ? attr[:value] : 0)
      }
    end

    def lists=(attrs)
      @lists = attrs.map { |attr|
        define_variable(attr[:name], List.new(attr.key?(:value) ? attr[:value] : []))
      }
    end

    def list(name)
      instance_eval(name)
    end

    def koshien
      Koshien.instance
    end

    def method_missing(name, *args)
      warn "no method error: `#{name}(#{args.inspect})'"
      IgnoreMethodMissing.new
    end

    def respond_to_missing?(sym, include_private)
      super
    end

    private

    def define_variable(name, value)
      name = "@#{name}"
      instance_variable_set(name, value)
      name
    end
  end
end
