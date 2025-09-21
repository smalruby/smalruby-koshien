require "rails_helper"

RSpec.describe "GameMap Queries", type: :request do
  let!(:game_map_1) { create(:game_map, name: "テストマップ1") }
  let!(:game_map_2) { create(:game_map, name: "テストマップ2") }

  describe "gameMaps query" do
    let(:query) do
      <<~GRAPHQL
        query {
          gameMaps {
            name
            description
            mapData
            mapHeight
            goalPosition {
              x
              y
            }
            size {
              width
              height
            }
            createdAt
            updatedAt
          }
        }
      GRAPHQL
    end

    it "全てのGameMapを返す" do
      post "/graphql", params: {query: query}

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json["data"]["gameMaps"]).to be_present
      expect(json["data"]["gameMaps"].size).to eq(2)

      map_names = json["data"]["gameMaps"].map { |map| map["name"] }
      expect(map_names).to include(game_map_1.name, game_map_2.name)
    end

    it "各GameMapの属性が正しく返される" do
      post "/graphql", params: {query: query}

      json = JSON.parse(response.body)
      first_map = json["data"]["gameMaps"].first

      expect(first_map["name"]).to be_present
      expect(first_map["mapData"]).to be_an(Array)
      expect(first_map["goalPosition"]).to have_key("x")
      expect(first_map["goalPosition"]).to have_key("y")
      expect(first_map["size"]).to have_key("width")
      expect(first_map["size"]).to have_key("height")
      expect(first_map["createdAt"]).to be_present
      expect(first_map["updatedAt"]).to be_present
    end

    it "mapDataが正しい2次元配列形式で返される" do
      post "/graphql", params: {query: query}

      json = JSON.parse(response.body)
      first_map = json["data"]["gameMaps"].first
      map_data = first_map["mapData"]

      expect(map_data).to be_an(Array)
      expect(map_data.first).to be_an(Array) if map_data.any?
      map_data.each do |row|
        expect(row).to be_an(Array)
        row.each do |cell|
          expect(cell).to be_an(Integer)
        end
      end
    end
  end
end
