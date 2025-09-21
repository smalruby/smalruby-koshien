# frozen_string_literal: true

module Types
  class QueryType < Types::BaseObject
    field :node, Types::NodeType, null: true, description: "Fetches an object given its ID." do
      argument :id, ID, required: true, description: "ID of the object."
    end

    def node(id:)
      context.schema.object_from_id(id, context)
    end

    field :nodes, [Types::NodeType, null: true], null: true, description: "Fetches a list of objects given a list of IDs." do
      argument :ids, [ID], required: true, description: "IDs of the objects."
    end

    def nodes(ids:)
      ids.map { |id| context.schema.object_from_id(id, context) }
    end

    # PlayerAi queries
    field :available_player_ais, [Types::PlayerAiType], null: false,
      description: "Get available player AIs"
    def available_player_ais
      PlayerAi.available
    end

    field :preset_player_ais, [Types::PlayerAiType], null: false,
      description: "Get preset player AIs"
    def preset_player_ais
      PlayerAi.preset.available
    end

    # GameMap queries
    field :game_maps, [Types::GameMapType], null: false,
      description: "Get all game maps"
    def game_maps
      GameMap.all
    end

    field :games, [Types::GameType], null: false,
      description: "Get all games" do
      argument :limit, Integer, required: false, default_value: 10
      argument :offset, Integer, required: false, default_value: 0
    end
    def games(limit: 10, offset: 0)
      Game.recent.limit(limit).offset(offset)
    end
  end
end
