module Mutations
  class CreateGame < BaseMutation
    argument :first_player_ai_id, ID, required: true
    argument :second_player_ai_id, ID, required: true
    argument :game_map_id, ID, required: true

    field :game, Types::GameType, null: true
    field :errors, [String], null: false

    def resolve(first_player_ai_id:, second_player_ai_id:, game_map_id:)
      first_ai = PlayerAi.find(first_player_ai_id)
      second_ai = PlayerAi.find(second_player_ai_id)
      game_map = GameMap.find(game_map_id)

      game = Game.new(
        first_player_ai: first_ai,
        second_player_ai: second_ai,
        game_map: game_map,
        status: :waiting_for_players
      )

      game.generate_battle_url

      if game.save
        {
          game: game,
          errors: []
        }
      else
        {
          game: nil,
          errors: game.errors.full_messages
        }
      end
    rescue ActiveRecord::RecordNotFound => e
      {
        game: nil,
        errors: ["Record not found: #{e.message}"]
      }
    rescue StandardError => e
      {
        game: nil,
        errors: [e.message]
      }
    end
  end
end