module Mutations
  class UploadGameMapThumbnail < BaseMutation
    description "Upload a thumbnail for a game map"

    argument :game_map_id, ID, required: true, loads: Types::GameMapType, as: :game_map, description: "The Global ID of the game map"
    argument :signed_id, String, required: true, description: "The signed ID from direct upload"

    field :game_map, Types::GameMapType, null: true
    field :errors, [String], null: false

    def resolve(game_map:, signed_id:)
      blob = ActiveStorage::Blob.find_signed(signed_id)
      game_map.thumbnail.attach(blob)

      {
        game_map: game_map,
        errors: []
      }
    rescue ActiveStorage::FileNotFoundError
      {
        game_map: nil,
        errors: ["Invalid signed ID"]
      }
    end
  end
end
