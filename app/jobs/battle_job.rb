class BattleJob < ApplicationJob
  queue_as :default

  def perform(game_id)
    game = Game.find(game_id)

    Rails.logger.info "Starting battle for game #{game_id}"

    begin
      # Initialize game engine
      game_engine = GameEngine.new(game)

      # Execute the battle
      result = game_engine.execute_battle

      # Update game status based on result
      if result[:success]
        game.update!(
          status: :completed,
          winner: result[:winner],
          completed_at: Time.current
        )
        Rails.logger.info "Battle completed for game #{game_id}, winner: #{result[:winner]}"
      else
        game.update!(status: :cancelled)
        Rails.logger.error "Battle failed for game #{game_id}: #{result[:error]}"
      end
    rescue => e
      Rails.logger.error "Battle job failed for game #{game_id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      game.update!(status: :cancelled)
      raise e
    end
  end
end
