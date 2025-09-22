require "singleton"
require "logger"

class AILib
  include Singleton

  attr_accessor :player_name

  attr_reader :logger

  def initialize
    @logger = Logger.new($stdout)
    @logger.level = Logger::INFO
    @player_name = nil
  end

  # These are stub methods that return nil or default values
  # since we're not using the actual game server communication
  # but need the methods to exist for koshien.rb compatibility

  def connectGame
    logger.info("connectGame called (stub)")
    nil
  end

  def get_map_area(x, y)
    logger.info("get_map_area called with #{x}, #{y} (stub)")
    nil
  end

  def move_to(x, y)
    logger.info("move_to called with #{x}, #{y} (stub)")
    nil
  end

  def set_dynamite(x, y)
    logger.info("set_dynamite called with #{x}, #{y} (stub)")
    nil
  end

  def set_bomb(x, y)
    logger.info("set_bomb called with #{x}, #{y} (stub)")
    nil
  end

  def turn_over
    logger.info("turn_over called (stub)")
    nil
  end

  def calc_route(args = {})
    logger.info("calc_route called with #{args} (stub)")
    []
  end

  def map(x, y)
    logger.info("map called with #{x}, #{y} (stub)")
    -1
  end

  def map_all
    logger.info("map_all called (stub)")
    ""
  end

  def locate_objects(args = {})
    logger.info("locate_objects called with #{args} (stub)")
    []
  end

  def other_player_pos
    logger.info("other_player_pos called (stub)")
    nil
  end

  def enemy_pos
    logger.info("enemy_pos called (stub)")
    nil
  end

  def goal
    logger.info("goal called (stub)")
    nil
  end

  def x
    logger.info("x called (stub)")
    0
  end

  def y
    logger.info("y called (stub)")
    0
  end

  def set_message(msg)
    logger.info("Message: #{msg}")
    nil
  end
end
