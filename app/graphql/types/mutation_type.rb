# frozen_string_literal: true

module Types
  class MutationType < Types::BaseObject
    field :register_player_ai, mutation: Mutations::RegisterPlayerAi
    field :create_game, mutation: Mutations::CreateGame
    field :upload_game_map_thumbnail, mutation: Mutations::UploadGameMapThumbnail
  end
end
