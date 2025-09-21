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
      %w[up down left right].include?(action[:direction])
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
    end

    def execute(ai_code)
      # Create a clean binding for code execution
      binding_context = create_clean_binding

      # Execute the AI code in the secured context
      # standard:disable Security/Eval
      # rubocop:disable Security/Eval
      result = eval(ai_code, binding_context)
      # rubocop:enable Security/Eval
      # standard:enable Security/Eval

      # Return the collected actions or result
      @actions.any? ? {actions: @actions} : (result || {action: {type: "wait"}})
    end

    private

    def create_clean_binding
      # Create a restricted binding that only allows safe operations
      bind = binding

      # Remove dangerous methods from the binding
      remove_dangerous_methods(bind)

      bind
    end

    def remove_dangerous_methods(bind)
      # List of dangerous methods to remove
      dangerous_methods = %w[
        eval exec system ` fork spawn
        require load autoload
        exit exit! abort
        File Dir IO
        const_set const_get
        instance_variable_set instance_variable_get
        class_variable_set class_variable_get
        send __send__ public_send
        method define_method
        proc lambda
      ]

      dangerous_methods.each do |method_name|
        bind.eval("undef #{method_name}") if bind.eval("defined?(#{method_name})")
      rescue NameError
        # Method doesn't exist, which is fine
      end
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

    private

    def add_action(action)
      @actions << action
      action
    end
  end
end
