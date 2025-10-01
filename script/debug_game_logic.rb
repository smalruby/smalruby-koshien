#!/usr/bin/env ruby
# frozen_string_literal: true

# Debug script for testing game logic with preset AI and sample map
require_relative "../config/environment"
require "optparse"

class GameLogicDebugger
  def initialize(options = {})
    @results = {}
    @options = options
  end

  def run
    puts "🎮 Game Logic Debug Script"
    puts "=" * 50

    # Display selected options
    display_options

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

  def display_options
    puts "\n📋 Selected Options:"
    puts "   Map: #{@options[:map] || "2024サンプルマップ1 (default)"}"
    puts "   Player 1: #{@options[:player1] || "ゴール優先AI (default)"}"
    puts "   Player 2: #{@options[:player2] || "アイテム優先AI (default)"}"
    puts "   Verbose: #{@options[:verbose] ? "enabled" : "disabled"}"
    puts
  end

  private

  def cleanup_test_data
    puts "\n🧹 Checking for existing test data..."

    begin
      # Count existing debug games but don't delete them
      existing_games = Game.where("battle_url LIKE ?", "%debug-test%")
      puts "   Found #{existing_games.count} existing debug games in database"

      if existing_games.count > 0
        puts "   ℹ️  Note: Previous debug games exist but will not be auto-deleted"
        puts "   ℹ️  To manually clean: rails runner 'Game.where(\"battle_url LIKE ?\", \"%debug-test%\").destroy_all'"
        puts "   ℹ️  This avoids foreign key constraint issues during automated testing"
      else
        puts "   ✓ No existing debug games found"
      end
    rescue => e
      puts "   ⚠️  Database check error: #{e.message}"
    end
  end

  def setup_test_data
    puts "\n🔧 Setting up test data..."

    # Select GameMap based on options or default
    map_name = @options[:map] || "2024サンプルマップ1"
    @game_map = if /^\d+$/.match?(map_name)
      # If numeric, assume it's a map ID
      GameMap.find_by(id: map_name.to_i)
    else
      # Otherwise, search by name
      GameMap.find_by(name: map_name)
    end
    raise "GameMap '#{map_name}' not found" unless @game_map

    # Select first PlayerAI based on options or default
    player1_name = @options[:player1] || "ゴール優先AI"
    @first_player_ai = if /^\d+$/.match?(player1_name)
      # If numeric, assume it's a PlayerAI ID
      PlayerAi.find_by(id: player1_name.to_i)
    else
      # Otherwise, search by name (prioritize system AIs)
      PlayerAi.find_by(name: player1_name, author: "system") ||
        PlayerAi.find_by(name: player1_name)
    end
    raise "PlayerAI '#{player1_name}' not found" unless @first_player_ai

    # Select second PlayerAI based on options or default
    player2_name = @options[:player2] || "アイテム優先AI"
    @second_player_ai = if /^\d+$/.match?(player2_name)
      # If numeric, assume it's a PlayerAI ID
      PlayerAi.find_by(id: player2_name.to_i)
    else
      # Otherwise, search by name (prioritize system AIs)
      PlayerAi.find_by(name: player2_name, author: "system") ||
        PlayerAi.find_by(name: player2_name)
    end
    raise "PlayerAI '#{player2_name}' not found" unless @second_player_ai

    # Create game
    @game = Game.create!(
      first_player_ai: @first_player_ai,
      second_player_ai: @second_player_ai,
      game_map: @game_map,
      status: :in_progress,
      battle_url: "https://debug-test.example.com/#{SecureRandom.hex(8)}"
    )

    puts "   ✓ Using game map: #{@game_map.name} (ID: #{@game_map.id})"
    puts "   ✓ Using AI 1: #{@first_player_ai.name} (ID: #{@first_player_ai.id})"
    puts "   ✓ Using AI 2: #{@second_player_ai.name} (ID: #{@second_player_ai.id})"
    puts "   ✓ Created game: #{@game.id}"

    if @options[:verbose]
      puts "\n   📋 Detailed Information:"
      puts "      Game Map Details:"
      puts "         Size: #{@game_map.map_data.size}x#{@game_map.map_data[0]&.size}"
      puts "         Goal: (#{@game_map.goal_position["x"]}, #{@game_map.goal_position["y"]})"

      puts "      Player AI 1 Details:"
      puts "         Code length: #{@first_player_ai.code.length} characters"
      puts "         Author: #{@first_player_ai.author}"

      puts "      Player AI 2 Details:"
      puts "         Code length: #{@second_player_ai.code.length} characters"
      puts "         Author: #{@second_player_ai.author}"
    end
  end

  def run_battle
    puts "\n⚔️  Running battle..."
    puts "   Game ID: #{@game.id}"
    puts "   Map: #{@game_map.name} (#{@game_map.map_data.size}x#{@game_map.map_data[0].size})"
    puts "   Goal position: #{@game_map.goal_position}"
    puts "   AI 1: #{@first_player_ai.name}"
    puts "   AI 2: #{@second_player_ai.name}"

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
        puts "      Status: #{player.status}"

        # Show timeout turn if player timed out
        if player.status == "timeout"
          # Find the turn where timeout occurred by checking game events
          timeout_events = GameEvent.joins(:game_turn)
            .where(game_turns: {game_round_id: round.id})
            .where(event_type: "AI_TIMEOUT")
            .where("event_data->>'player_id' = ?", player.id.to_s)

          if timeout_events.any?
            timeout_turn = timeout_events.first.game_turn.turn_number
            puts "      Timeout Turn: #{timeout_turn}"
          end
        end

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

      # Detailed turn-by-turn analysis in verbose mode
      if @options[:verbose] && turns.any?
        puts "\n   📍 Turn-by-Turn Movement Analysis:"
        turns.limit(10).each do |turn|
          turn_players = turn.players.includes(:player_ai)
          turn_players.each do |player|
            ai_name = player.player_ai.name.split(" - ").last
            puts "      Turn #{turn.turn_number} - #{ai_name}: (#{player.position_x}, #{player.position_y})"
          end
        end
        if turns.count > 10
          puts "      ... (#{turns.count - 10} more turns) ..."
          last_turns = turns.last(5)
          last_turns.each do |turn|
            turn_players = turn.players.includes(:player_ai)
            turn_players.each do |player|
              ai_name = player.player_ai.name.split(" - ").last
              puts "      Turn #{turn.turn_number} - #{ai_name}: (#{player.position_x}, #{player.position_y})"
            end
          end
        end
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

  class << self
    private

    def list_available_resources
      puts "🗺️  Available GameMaps:"
      GameMap.order(:id).each do |map|
        puts "   ID: #{map.id.to_s.rjust(2)} - #{map.name}"
      end

      puts "\n🤖 Available PlayerAIs (System):"
      PlayerAi.where(author: "system").order(:id).each do |ai|
        puts "   ID: #{ai.id.to_s.rjust(2)} - #{ai.name}"
      end

      puts "\n👤 Available PlayerAIs (User):"
      user_ais = PlayerAi.where.not(author: "system").order(:id)
      if user_ais.any?
        user_ais.each do |ai|
          puts "   ID: #{ai.id.to_s.rjust(2)} - #{ai.name} (by #{ai.author})"
        end
      else
        puts "   No user-created AIs found"
      end
    end
  end
end

# Parse command line options
options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: #{$0} [options]"

  opts.on("-m", "--map MAP", "GameMap name or ID (default: 2024サンプルマップ1)") do |map|
    options[:map] = map
  end

  opts.on("-1", "--player1 AI", "First PlayerAI name or ID (default: ゴール優先AI)") do |ai|
    options[:player1] = ai
  end

  opts.on("-2", "--player2 AI", "Second PlayerAI name or ID (default: アイテム優先AI)") do |ai|
    options[:player2] = ai
  end

  opts.on("-v", "--verbose", "Enable verbose output") do
    options[:verbose] = true
  end

  opts.on("-l", "--list", "List available maps and AIs") do
    GameLogicDebugger.list_available_resources
    exit
  end

  opts.on("-h", "--help", "Show this help message") do
    puts opts
    puts "\nExamples:"
    puts "  #{$0}                              # Use default settings"
    puts "  #{$0} -m 1 -1 'ゴール優先AI' -2 2   # Use map ID 1, AI name, AI ID 2"
    puts "  #{$0} --list                       # Show available resources"
    puts "  #{$0} -v                           # Enable verbose output"
    puts
    puts "Available GameMaps and PlayerAIs can be listed with --list option."
    exit
  end
end.parse!

# Run the debugger
if __FILE__ == $0
  debugger = GameLogicDebugger.new(options)
  debugger.run
end
