module Types
  class GameMapType < Types::BaseObject
    field :id, ID, null: false
    field :name, String, null: false
    field :description, String, null: true
    field :thumbnail_url, String, null: true
    field :map_data, [[Integer]], null: false
    field :map_height, [[Integer]], null: true
    field :goal_position, Types::PositionType, null: false
    field :size, Types::MapSizeType, null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false

    def goal_position
      pos = object.goal_position_object
      pos ? { x: pos[:x], y: pos[:y] } : { x: 0, y: 0 }
    end

    def size
      object.size
    end
  end
end