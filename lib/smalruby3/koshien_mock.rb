# frozen_string_literal: true

require "singleton"

module Smalruby3
  # Mock implementation of Koshien for testing purposes
  # This class provides simple stub behaviors for all API methods
  # to enable unit testing without requiring full game engine setup
  #
  # Usage:
  #   ENV["KOSHIEN_MOCK_MODE"] = "true"
  #   koshien = Smalruby3::Koshien.instance  # Returns KoshienMock instance
  class KoshienMock
    include Singleton

    # Override API methods with test stub behaviors

    def connect_game(name:)
      @player_name = name
      log("プレイヤー名を設定します: name=\"#{name}\"")
    end

    def get_map_area(position)
      log("Get map area: #{position}")
      nil
    end

    def move_to(position)
      log("Move to: #{position}")
    end

    def set_dynamite(position = nil)
      log("Set dynamite at: #{position}")
    end

    def set_bomb(position = nil)
      log("Set bomb at: #{position}")
    end

    def turn_over
      log("Turn over")
    end

    def position(x, y)
      "#{x}:#{y}"
    end

    def calc_route(result:, src: player, dst: goal, except_cells: nil)
      result ||= List.new

      # Parse src and dst coordinates
      src_coords = parse_position_string(src)
      dst_coords = parse_position_string(dst)

      # Simple stub for testing - return direct path
      route = [[src_coords[0], src_coords[1]], [dst_coords[0], dst_coords[1]]]

      # Convert route to position strings and update result list
      result.replace(route.map { |coords| "#{coords[0]}:#{coords[1]}" })
      result
    end

    def map(position)
      -1  # Unknown/unexplored
    end

    def map_all
      # Return 15x15 map with all cells as unexplored (-1 represented as "-")
      # Format: "---------------,---------------,..." (15 rows of 15 chars each)
      Array.new(15) { "-" * 15 }.join(",")
    end

    def other_player
      nil
    end

    def other_player_x
      nil
    end

    def other_player_y
      nil
    end

    def enemy
      nil
    end

    def enemy_x
      nil
    end

    def enemy_y
      nil
    end

    def goal
      "14:14"
    end

    def goal_x
      14
    end

    def goal_y
      14
    end

    def player
      position(0, 0)
    end

    def player_x
      0
    end

    def player_y
      0
    end

    def set_message(message)
      log("Message: #{message}")
    end

    def locate_objects(result:, cent: nil, sq_size: nil, objects: nil)
      result ||= List.new
      # Simple stub - return empty list
      result.replace([])
      log("Locate objects: cent=#{cent}, sq_size=#{sq_size}, objects=#{objects}")
      result
    end

    def map_from(position, from)
      log("Map from: position=#{position}, from=#{from}")
      -1  # Unknown/unexplored
    end

    def position_of_x(position)
      coords = parse_position_string(position)
      coords[0]
    end

    def position_of_y(position)
      coords = parse_position_string(position)
      coords[1]
    end

    def object(name)
      # Simplified object lookup for testing
      case name
      when "unknown", "未探索のマス", "みたんさくのマス"
        -1
      when "space", "空間", "くうかん"
        0
      when "wall", "壁", "かべ"
        1
      when "goal", "ゴール"
        3
      when "water", "水たまり", "みずたまり"
        4
      when "breakable wall", "壊せる壁", "こわせるかべ"
        5
      else
        -1
      end
    end

    private

    def parse_position_string(pos_str)
      if pos_str.is_a?(String) && pos_str.include?(":")
        pos_str.split(":").map(&:to_i)
      else
        [0, 0]  # default fallback
      end
    end

    def log(message)
      # Simple logging for testing
      puts message
    end
  end
end
