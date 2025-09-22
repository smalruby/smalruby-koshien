class AiEngine
  include GameConstants

  EXECUTION_TIMEOUT = TURN_DURATION # 10 seconds
  ALLOWED_METHODS = %w[
    move_up move_down move_left move_right
    use_dynamite use_bomb
    get_player_info get_enemy_info get_map_info
    get_item_info get_turn_info
  ].freeze

  class AiExecutionError < StandardError; end
  class AiTimeoutError < AiExecutionError; end
  class AiSecurityError < AiExecutionError; end

  def initialize
    @execution_context = nil
    # Load Smalruby3 Koshien library
    load_koshien_library
  end

  def execute_ai(player:, game_state:, turn:)
    Rails.logger.debug "Executing AI for player #{player.id}"

    begin
      # Create secured execution context
      context = create_execution_context(player, game_state, turn)

      # Execute AI code with timeout
      result = execute_with_timeout(player.player_ai.code, context)

      # Validate and return result
      validate_ai_result(result)
    rescue Timeout::Error
      Rails.logger.error "AI execution timeout for player #{player.id}"
      raise AiTimeoutError, "AI execution timed out"
    rescue SecurityError => e
      Rails.logger.error "AI security violation for player #{player.id}: #{e.message}"
      raise AiSecurityError, "AI code violated security policy: #{e.message}"
    rescue SyntaxError => e
      Rails.logger.error "AI syntax error for player #{player.id}: #{e.message}"
      raise AiExecutionError, "AI syntax error: #{e.message}"
    rescue => e
      Rails.logger.error "AI execution error for player #{player.id}: #{e.message}"
      raise AiExecutionError, "AI execution failed: #{e.message}"
    end
  end

  # New turn-over based execution method
  def execute_ai_with_turn_over(player:, game_state:, turn:)
    Rails.logger.debug "Executing AI with turn_over for player #{player.id}"

    begin
      # Create secured execution context with turn_over support
      context = create_execution_context(player, game_state, turn)

      # Execute AI code with turn_over handling
      result = execute_with_turn_over_handling(player.player_ai.code, context)

      # Validate and return result
      validate_ai_result(result)
    rescue Timeout::Error
      Rails.logger.error "AI execution timeout for player #{player.id}"
      raise AiTimeoutError, "AI execution timed out"
    rescue SecurityError => e
      Rails.logger.error "AI security violation for player #{player.id}: #{e.message}"
      raise AiSecurityError, "AI code violated security policy: #{e.message}"
    rescue SyntaxError => e
      Rails.logger.error "AI syntax error for player #{player.id}: #{e.message}"
      raise AiExecutionError, "AI syntax error: #{e.message}"
    rescue => e
      Rails.logger.error "AI execution error for player #{player.id}: #{e.message}"
      raise AiExecutionError, "AI execution failed: #{e.message}"
    end
  end

  private

  def create_execution_context(player, game_state, turn)
    AiExecutionContext.new(player, game_state, turn)
  end

  def execute_with_timeout(ai_code, context)
    result = nil

    # Execute with timeout
    Timeout.timeout(EXECUTION_TIMEOUT) do
      result = context.execute(ai_code)
    end

    result
  end

  # Execute AI code with turn_over handling - simple approach
  def execute_with_turn_over_handling(ai_code, context)
    result = nil
    turn_over_count = 0
    max_turn_overs = 50  # Prevent infinite turn_over calls
    collected_actions = []

    # Execute with timeout for the entire AI execution
    Timeout.timeout(EXECUTION_TIMEOUT) do
      # Execute the AI code and collect all actions until a move is found
      loop do
        turn_over_count += 1

        if turn_over_count > max_turn_overs
          Rails.logger.warn "AI exceeded max turn_over calls (#{max_turn_overs}), stopping"
          break
        end

        # Execute until next turn_over
        turn_result = catch(:turn_over) do
          context.execute_full_ai_code(ai_code)
        end

        # If turn_over was called, turn_result will be nil
        if turn_result.nil?
          Rails.logger.debug "AI called turn_over #{turn_over_count} times"

          # Get actions collected since last turn_over
          iteration_actions = context.get_and_clear_iteration_actions
          collected_actions.concat(iteration_actions)

          # Check if we have a move action in collected actions
          move_actions = collected_actions.select { |action| action[:type] == "move" }
          if move_actions.any?
            # Found a move action, this completes the turn
            result = {actions: collected_actions}
            break
          elsif iteration_actions.any?
            # Had other actions (search, etc.), continue
            Rails.logger.debug "AI performed non-move actions: #{iteration_actions.map { |a| a[:type] }}, continuing..."
            # Continue to next turn_over
          else
            # No actions this iteration, continue
            Rails.logger.debug "AI called turn_over with no actions, continuing..."
          end
        else
          # AI code completed without calling turn_over
          iteration_actions = context.get_and_clear_iteration_actions
          collected_actions.concat(iteration_actions)

          result = if collected_actions.any?
            {actions: collected_actions}
          else
            turn_result || {action: {type: "wait"}}
          end
          break
        end
      end
    end

    # Return collected actions or default wait action
    result || {action: {type: "wait"}}
  end

  def validate_ai_result(result)
    # Ensure result is a hash with valid actions
    unless result.is_a?(Hash)
      raise AiExecutionError, "AI must return a hash"
    end

    # Validate action format
    if result[:action] && !valid_action?(result[:action])
      raise AiExecutionError, "Invalid action: #{result[:action]}"
    end

    result
  end

  def valid_action?(action)
    return false unless action.is_a?(Hash)
    return false unless action[:type]

    case action[:type]
    when "move"
      if action[:direction]
        %w[up down left right].include?(action[:direction])
      elsif action[:target_x] && action[:target_y]
        action[:target_x].is_a?(Integer) && action[:target_y].is_a?(Integer)
      else
        false
      end
    when "use_item"
      %w[dynamite bomb].include?(action[:item])
    when "wait"
      true
    else
      false
    end
  end

  # Secured execution context for AI code
  class AiExecutionContext
    include GameConstants

    def initialize(player, game_state, turn)
      @player = player
      @game_state = game_state
      @turn = turn
      @actions = []
      @iteration_actions = []
      @turn_counter = 0
      @move_count = 0  # Track moves per turn
    end

    def execute(ai_code)
      # Execute the AI code in the secured context
      # Block dangerous methods but allow require "smalruby3"
      dangerous_methods = %w[system exec ` eval instance_eval class_eval load]
      dangerous_methods.each do |method|
        if ai_code.include?(method)
          raise SecurityError, "Dangerous method '#{method}' is not allowed"
        end
      end

      # Remove require statements that are not needed in AI context
      ai_code = ai_code.gsub(/require\s+["']smalruby3["']/, "")

      # standard:disable Security/Eval
      # rubocop:disable Security/Eval
      result = catch(:turn_over) do
        eval(ai_code)
      end
      # rubocop:enable Security/Eval
      # standard:enable Security/Eval

      # Return the collected actions or result
      @actions.any? ? {actions: @actions} : (result || {action: {type: "wait"}})
    end

    # Execute the full AI code (designed for fiber-based execution)
    def execute_full_ai_code(ai_code)
      # Block dangerous methods but allow require "smalruby3"
      dangerous_methods = %w[system exec ` eval instance_eval class_eval load]
      dangerous_methods.each do |method|
        if ai_code.include?(method)
          raise SecurityError, "Dangerous method '#{method}' is not allowed"
        end
      end

      # Remove require statements that are not needed in AI context
      ai_code = ai_code.gsub(/require\s+["']smalruby3["']/, "")

      Rails.logger.debug "Executing AI code in isolated context"

      # standard:disable Security/Eval
      # rubocop:disable Security/Eval
      result = eval(ai_code)
      # rubocop:enable Security/Eval
      # standard:enable Security/Eval

      Rails.logger.debug "AI code execution completed successfully"
      result
    end

    # Reset state for a new iteration
    def reset_for_new_iteration
      @iteration_actions = []
    end

    # Get actions from current iteration and clear them
    def get_and_clear_iteration_actions
      actions = @iteration_actions.dup
      @iteration_actions = []
      actions
    end

    # Get actions from current iteration
    def get_iteration_actions
      @iteration_actions.dup
    end

    # Safe API methods for AI code

    def move_up
      add_action({type: "move", direction: "up"})
    end

    def move_down
      add_action({type: "move", direction: "down"})
    end

    def move_left
      add_action({type: "move", direction: "left"})
    end

    def move_right
      add_action({type: "move", direction: "right"})
    end

    def use_dynamite
      add_action({type: "use_item", item: "dynamite"})
    end

    def use_bomb
      add_action({type: "use_item", item: "bomb"})
    end

    def wait
      add_action({type: "wait"})
    end

    def get_player_info
      @game_state[:player].dup
    end

    def get_enemy_info
      @game_state[:enemies].map(&:dup)
    end

    def get_map_info
      @game_state[:map].dup
    end

    def get_item_info
      @game_state[:items].dup
    end

    def get_turn_info
      {
        turn: @game_state[:turn],
        round: @game_state[:round]
      }
    end

    def log(message)
      Rails.logger.info "AI Player #{@player.id}: #{message}"
    end

    # Koshien compatibility methods
    def get_my_position
      {"x" => @player.position_x, "y" => @player.position_y}
    end

    def get_goal_position
      goal_pos = @game_state[:goal]
      return nil if goal_pos.nil?

      # Convert string keys to numeric values if needed
      {
        "x" => goal_pos["x"].to_i,
        "y" => goal_pos["y"].to_i
      }
    end

    def get_turn_number
      @game_state[:turn]
    end

    def get_round_number
      @game_state[:round]
    end

    # Smalruby3 framework compatibility methods
    def Stage(*args, &block)
      # Don't actually create stages in AI context to avoid conflicts
      Rails.logger.debug "AI attempting to create Stage, ignoring"
      if block
        # Execute the block in current context to capture method definitions
        instance_eval(&block)
      end
      nil
    end

    def Sprite(*args, &block)
      # Don't actually create sprites in AI context to avoid conflicts
      Rails.logger.debug "AI attempting to create Sprite, ignoring"
      if block
        # Execute the block in current context to capture method definitions
        instance_eval(&block)
      end
      nil
    end

    def list(name)
      @lists ||= {}
      @lists[name] ||= MockList.new
    end

    def koshien
      @koshien ||= MockKoshien.new(self)
    end

    private

    def add_action(action)
      # Validate move restrictions: only one move per turn
      if action[:type] == "move"
        @move_count += 1
        if @move_count > 1
          Rails.logger.warn "AI attempted multiple moves in one turn, ignoring extra move"
          return action
        end
      end

      # Add to both overall actions and current iteration actions
      @actions << action
      @iteration_actions << action
      action
    end

    # Mock classes for smalruby3 framework compatibility
    class MockStage
      def self.new(*args, &block)
        instance = allocate
        instance.instance_eval(&block) if block
        instance
      end

      def stage?
        true
      end
    end

    class MockSprite
      def self.new(*args, &block)
        instance = allocate
        instance.instance_eval(&block) if block
        instance
      end

      def stage?
        false
      end

      def name
        @name ||= "sprite"
      end
    end

    class MockList
      def initialize(initial_data = [])
        @data = initial_data.dup
      end

      def length
        @data.length
      end

      def [](index)
        @data[index]
      end

      def []=(index, value)
        @data[index] = value
      end

      def push(value)
        @data.push(value)
      end

      def clear
        @data.clear
      end

      def replace(new_data)
        @data = new_data.dup
      end
    end

    class MockKoshien
      def initialize(context)
        @context = context
      end

      def connect_game(name:)
        # Stub implementation
        nil
      end

      def get_map_area(position)
        # Implementation for map area exploration
        Rails.logger.debug "AI exploring map area: #{position}"
        # Add exploration action (non-move action)
        @context.add_action({type: "explore", target: position})
        nil
      end

      def move_to(position)
        if position
          # Extract coordinates from position string like "3:4"
          if position.is_a?(String) && position.include?(":")
            x, y = position.split(":").map(&:to_i)
            @context.add_action({type: "move", target_x: x, target_y: y})
          end
        end
        nil
      end

      def turn_over
        # End execution by throwing a special exception that we catch
        throw :turn_over
      end

      def calc_route(result:, src: nil, dst: nil, except_cells: nil)
        # Simple pathfinding stub - just return direct path
        src_pos = parse_position(src || player)
        dst_pos = parse_position(dst || goal)

        if src_pos && dst_pos
          # Simple direct path
          path = [format_position(src_pos)]

          # Add one step toward destination
          next_x = src_pos[:x]
          next_y = src_pos[:y]

          if src_pos[:x] < dst_pos[:x]
            next_x += 1
          elsif src_pos[:x] > dst_pos[:x]
            next_x -= 1
          elsif src_pos[:y] < dst_pos[:y]
            next_y += 1
          elsif src_pos[:y] > dst_pos[:y]
            next_y -= 1
          end

          path << format_position({x: next_x, y: next_y})
          path << format_position(dst_pos)

          result&.replace(path)
        elsif result
          result.replace([])
        end

        nil
      end

      def locate_objects(result:, cent: nil, sq_size: 5, objects: "ABCD")
        # Stub implementation - return empty list for now
        result&.replace([])
        nil
      end

      def player
        my_pos = @context.get_my_position
        "#{my_pos["x"]}:#{my_pos["y"]}"
      end

      def goal
        goal_pos = @context.get_goal_position
        return nil unless goal_pos
        "#{goal_pos["x"]}:#{goal_pos["y"]}"
      end

      private

      def parse_position(pos_str)
        return nil unless pos_str
        if pos_str.include?(":")
          x, y = pos_str.split(":").map(&:to_i)
          {x: x, y: y}
        end
      end

      def format_position(pos)
        "#{pos[:x]}:#{pos[:y]}"
      end
    end
  end

  private

  def load_koshien_library
    # Load only the Koshien library, skip smalruby3 to avoid conflicts

    require Rails.root.join("lib", "smalruby3", "koshien")
  rescue LoadError => e
    Rails.logger.warn "Could not load Koshien library: #{e.message}"
  end
end
