module Types
  class PlayerAiType < Types::BaseObject
    field :name, String, null: false
    field :code, String, null: false
    field :author, String, null: true
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :expires_at, GraphQL::Types::ISO8601DateTime, null: false
    field :expired, Boolean, null: false
    field :preset, Boolean, null: false

    def expired
      object.expired?
    end

    def preset
      object.preset?
    end
  end
end
