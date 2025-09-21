module Types
  class GameType < Types::BaseObject
    field :id, ID, null: false
    field :first_player_ai, Types::PlayerAiType, null: false
    field :second_player_ai, Types::PlayerAiType, null: false
    field :game_map, Types::GameMapType, null: false
    field :status, Types::GameStatusEnum, null: false
    field :winner, Types::PlayerPositionEnum, null: true
    field :battle_url, String, null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :completed_at, GraphQL::Types::ISO8601DateTime, null: true
    field :finished, Boolean, null: false

    def finished
      object.finished?
    end
  end
end