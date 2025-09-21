module Mutations
  class CreateGame < BaseMutation
    argument :first_player_ai_id, ID, required: true, loads: Types::PlayerAiType, as: :first_player_ai
    argument :second_player_ai_id, ID, required: true, loads: Types::PlayerAiType, as: :second_player_ai
    argument :game_map_id, ID, required: true, loads: Types::GameMapType, as: :game_map

    field :game, Types::GameType, null: true
    field :errors, [String], null: false

    def resolve(first_player_ai:, second_player_ai:, game_map:)
      game = Game.new(
        first_player_ai: first_player_ai,
        second_player_ai: second_player_ai,
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
    rescue => e
      {
        game: nil,
        errors: [e.message]
      }
    end
  end
end
