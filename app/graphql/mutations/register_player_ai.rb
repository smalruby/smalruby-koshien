module Mutations
  class RegisterPlayerAi < BaseMutation
    argument :name, String, required: true
    argument :code, String, required: true
    argument :author, String, required: false

    field :player_ai, Types::PlayerAiType, null: true
    field :errors, [String], null: false

    def resolve(name:, code:, author: nil)
      player_ai = PlayerAi.new(
        name: name,
        code: code,
        author: author
      )

      if player_ai.save
        {
          player_ai: player_ai,
          errors: []
        }
      else
        {
          player_ai: nil,
          errors: player_ai.errors.full_messages
        }
      end
    rescue => e
      {
        player_ai: nil,
        errors: [e.message]
      }
    end
  end
end
