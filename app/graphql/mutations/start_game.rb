module Mutations
  class StartGame < BaseMutation
    argument :game_id, ID, required: true, loads: Types::GameType, as: :game

    field :game, Types::GameType, null: true
    field :errors, [String], null: false

    def resolve(game:)
      unless game.waiting_for_players?
        return {
          game: nil,
          errors: ["Game is not in waiting_for_players status"]
        }
      end

      game.status = :in_progress

      if game.save
        # バトルジョブを非同期で実行
        BattleJob.perform_later(game.id)

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
