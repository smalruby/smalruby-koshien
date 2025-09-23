require "singleton"

module Smalruby3
  class ExistStage < StandardError; end
  class ExistSprite < StandardError; end

  class World
    include Singleton

    attr_accessor :stage
    attr_accessor :sprites

    def initialize
      reset
    end

    def reset
      clear_sprites
    end

    def add_target(stage_or_sprite)
      if stage_or_sprite.stage?
        stage = stage_or_sprite
        raise ExistStage.new(stage) if @stage

        @stage = stage
      else
        sprite = stage_or_sprite
        raise ExistSprite.new(sprite) if @name_to_sprite.key?(sprite.name)

        @sprites << sprite
        @name_to_sprite[sprite.name] = sprite
      end
      stage_or_sprite
    end

    private

    def clear_sprites
      @stage = nil
      @sprites = []
      @name_to_sprite = {}
    end
  end
end
