#!/usr/bin/env ruby
# frozen_string_literal: true

# Debug script for testing game logic with preset AI and sample map
require_relative "../config/environment"

class GameLogicDebugger
  def initialize
    @results = {}
  end

  def run
    puts "🎮 Game Logic Debug Script"
    puts "=" * 50

    # Clean up existing data
    cleanup_test_data

    # Setup test data
    setup_test_data

    # Run battle
    run_battle

    # Analyze results
    analyze_results

    # Cleanup
    cleanup_test_data if ENV["CLEANUP"] != "false"

    puts "\n✅ Debug complete!"
  end

  private

  def cleanup_test_data
    puts "\n🧹 Cleaning up test data..."
    # Delete in correct order to avoid foreign key constraints
    games_to_delete = Game.where("battle_url LIKE ?", "%debug-test%")
    games_to_delete.each do |game|
      # Delete associated game rounds (cascades to players, enemies, turns, events)
      game.game_rounds.destroy_all
      game.destroy
    end

    PlayerAi.where("name LIKE ?", "%Debug Test%").destroy_all
    GameMap.where("name LIKE ?", "%Debug Test%").destroy_all
  rescue => e
    puts "   ⚠️  Cleanup warning: #{e.message}"
  end

  def setup_test_data
    puts "\n🔧 Setting up test data..."

    # Create sample map (similar to map_01) with unique name
    timestamp = Time.current.strftime("%Y%m%d_%H%M%S_%L")
    @game_map = GameMap.create!(
      name: "Debug Test Map #{timestamp}",
      description: "Debug test map based on sample map 01",
      map_data: [
        [0, 0, 0, 1, 0, 0, 0],
        [0, 1, 0, 0, 0, 1, 0],
        [0, 0, 0, 0, 0, 0, 0],
        [1, 0, 0, 3, 0, 0, 1],
        [0, 0, 0, 0, 0, 0, 0],
        [0, 1, 0, 0, 0, 1, 0],
        [0, 0, 0, 1, 0, 0, 0]
      ],
      map_height: Array.new(7) { Array.new(7, 0) },
      goal_position: {"x" => 3, "y" => 3}
    )

    # Create preset AIs with different strategies
    @first_player_ai = PlayerAi.create!(
      name: "Debug Test AI 1 - Goal Seeker #{timestamp}",
      author: "Debug Script",
      code: <<~RUBY
        # Goal-seeking AI using available methods
        my_pos = get_my_position
        goal_pos = get_goal_position

        if goal_pos.nil?
          # If no goal found, move right
          move_right
        else
          # Calculate direction to goal
          if my_pos["x"] < goal_pos["x"]
            move_right
          elsif my_pos["x"] > goal_pos["x"]
            move_left
          elsif my_pos["y"] < goal_pos["y"]
            move_down
          elsif my_pos["y"] > goal_pos["y"]
            move_up
          else
            # At goal, just wait
            wait
          end
        end
      RUBY
    )

    @second_player_ai = PlayerAi.create!(
      name: "Debug Test AI 2 - Explorer #{timestamp}",
      author: "Debug Script",
      code: <<~RUBY
        # Explorer AI with simple pattern
        turn = get_turn_number

        case turn % 4
        when 0
          move_right
        when 1
          move_down
        when 2
          move_left
        when 3
          move_up
        end
      RUBY
    )

    # Create game
    @game = Game.create!(
      first_player_ai: @first_player_ai,
      second_player_ai: @second_player_ai,
      game_map: @game_map,
      status: :in_progress,
      battle_url: "https://debug-test.example.com/#{SecureRandom.hex(8)}"
    )

    puts "   ✓ Created game map: #{@game_map.name}"
    puts "   ✓ Created AI 1: #{@first_player_ai.name}"
    puts "   ✓ Created AI 2: #{@second_player_ai.name}"
    puts "   ✓ Created game: #{@game.id}"
  end

  def run_battle
    puts "\n⚔️  Running battle..."
    puts "   Game ID: #{@game.id}"
    puts "   Map: #{@game_map.name} (#{@game_map.map_data.size}x#{@game_map.map_data[0].size})"
    puts "   Goal position: #{@game_map.goal_position}"

    # Initialize game engine
    game_engine = GameEngine.new(@game)

    # Execute battle
    start_time = Time.current
    @battle_result = game_engine.execute_battle
    end_time = Time.current

    @results[:execution_time] = end_time - start_time
    @results[:battle_result] = @battle_result

    puts "   ✓ Battle completed in #{@results[:execution_time].round(2)} seconds"
    puts "   ✓ Result: #{@battle_result[:success] ? "SUCCESS" : "FAILED"}"

    if @battle_result[:success]
      puts "   ✓ Winner: #{@battle_result[:winner]}"
    else
      puts "   ✗ Error: #{@battle_result[:error]}"
    end
  end

  def analyze_results
    puts "\n📊 Analysis Results"
    puts "-" * 30

    @game.reload

    # Basic game info
    puts "Game Status: #{@game.status}"
    puts "Game Winner: #{@game.winner || "None"}"
    puts "Execution Time: #{@results[:execution_time].round(2)}s"
    puts

    # Round analysis
    rounds = @game.game_rounds.includes(:players, :game_turns, :enemies)
    puts "Rounds Created: #{rounds.count}"

    rounds.each_with_index do |round, index|
      puts "\n🔄 Round #{round.round_number}:"
      puts "   Status: #{round.status}"
      puts "   Winner: #{round.winner || "No winner"}"
      puts "   Players: #{round.players.count}"
      puts "   Turns: #{round.game_turns.count}"
      puts "   Enemies: #{round.enemies.count}"

      # Player analysis
      round.players.includes(:player_ai).each do |player|
        ai_name = player.player_ai.name.split(" - ").last
        puts "   👤 #{ai_name}:"
        puts "      Position: (#{player.position_x}, #{player.position_y})"
        puts "      Score: #{player.score}"
        puts "      HP: #{player.hp}"
        puts "      Status: #{player.status}"
        puts "      Level: #{player.character_level}"
        puts "      Dynamite: #{player.dynamite_left}/#{GameConstants::N_DYNAMITE}"
        puts "      Bombs: #{player.bomb_left}/#{GameConstants::N_BOMB}"
      end

      # Turn analysis (show first few and last few)
      turns = round.game_turns.order(:turn_number)
      puts "\n   🎯 Turn Summary:"
      puts "      Total turns: #{turns.count}"
      if turns.any?
        puts "      First turn: #{turns.first.turn_number}"
        puts "      Last turn: #{turns.last.turn_number}"
        puts "      All finished: #{turns.all?(&:turn_finished?)}"
      end

      # Event analysis
      events = GameEvent.joins(:game_turn).where(game_turns: {game_round_id: round.id})
      event_counts = events.group(:event_type).count
      if event_counts.any?
        puts "\n   📝 Events:"
        event_counts.each do |event_type, count|
          puts "      #{event_type}: #{count}"
        end
      end
    end

    # Final positions vs goal
    puts "\n🎯 Goal Analysis:"
    goal_pos = @game_map.goal_position
    puts "Goal Position: (#{goal_pos["x"]}, #{goal_pos["y"]})"

    if rounds.any?
      final_round = rounds.last
      final_round.players.includes(:player_ai).each do |player|
        ai_name = player.player_ai.name.split(" - ").last
        distance = (player.position_x - goal_pos["x"]).abs + (player.position_y - goal_pos["y"]).abs
        reached_goal = distance == 0
        puts "#{ai_name}: (#{player.position_x}, #{player.position_y}) - Distance: #{distance} #{"🏆 GOAL!" if reached_goal}"
      end
    end

    # Performance metrics
    puts "\n⚡ Performance:"
    puts "Total Events: #{GameEvent.joins(game_turn: :game_round).where(game_rounds: {game_id: @game.id}).count}"
    puts "Average Turn Duration: #{(@results[:execution_time] / rounds.sum { |r| r.game_turns.count }).round(4)}s" if rounds.any?
  end
end

# Run the debugger
if __FILE__ == $0
  debugger = GameLogicDebugger.new
  debugger.run
end
