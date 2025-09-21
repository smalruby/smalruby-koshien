require "rails_helper"

RSpec.describe "Games Queries", type: :request do
  let!(:game_map) { create(:game_map) }
  let!(:player_ai_1) { create(:player_ai) }
  let!(:player_ai_2) { create(:player_ai) }
  let!(:game_1) { create(:game, game_map: game_map, first_player_ai: player_ai_1, second_player_ai: player_ai_2) }
  let!(:game_2) { create(:game, game_map: game_map, first_player_ai: player_ai_2, second_player_ai: player_ai_1) }

  describe "games query" do
    let(:query) do
      <<~GRAPHQL
        query($limit: Int, $offset: Int) {
          games(limit: $limit, offset: $offset) {
            battleUrl
            status
            winner
            completedAt
            firstPlayerAi {
              name
            }
            secondPlayerAi {
              name
            }
            gameMap {
              name
            }
          }
        }
      GRAPHQL
    end

    context "パラメータなしの場合" do
      it "デフォルトで10件のゲームを返す" do
        # 追加のゲームを作成して10件以上にする
        8.times do
          create(:game, game_map: game_map, first_player_ai: player_ai_1, second_player_ai: player_ai_2)
        end

        post "/graphql", params: {query: query}

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)

        expect(json["data"]["games"].size).to eq(10)
      end
    end

    context "limitパラメータ指定の場合" do
      let(:variables) { {limit: 1} }

      it "指定した件数のゲームを返す" do
        post "/graphql", params: {query: query, variables: variables.to_json}

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)

        if json["errors"]
          puts "GraphQL Errors: #{json["errors"]}"
        end

        expect(json["data"]).to be_present
        expect(json["data"]["games"]).to be_present
        expect(json["data"]["games"].size).to eq(1)
      end
    end

    context "offsetパラメータ指定の場合" do
      let(:variables) { {limit: 1, offset: 1} }

      it "オフセット後のゲームを返す" do
        post "/graphql", params: {query: query, variables: variables.to_json}

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)

        if json["errors"]
          puts "GraphQL Errors: #{json["errors"]}"
        end

        expect(json["data"]).to be_present
        expect(json["data"]["games"]).to be_present
        expect(json["data"]["games"].size).to eq(1)
        # 最新順なので、2番目に新しいゲームが返される
        expect(json["data"]["games"].first["battleUrl"]).to eq(game_1.battle_url)
      end
    end

    it "各ゲームの関連データが正しく返される" do
      post "/graphql", params: {query: query}

      json = JSON.parse(response.body)
      first_game = json["data"]["games"].first

      expect(first_game["battleUrl"]).to be_present
      expect(first_game["status"]).to be_present
      expect(first_game["firstPlayerAi"]["name"]).to be_present
      expect(first_game["secondPlayerAi"]["name"]).to be_present
      expect(first_game["gameMap"]["name"]).to be_present
    end

    it "ゲームが作成日時の降順で返される" do
      post "/graphql", params: {query: query}

      json = JSON.parse(response.body)
      games = json["data"]["games"]

      expect(games.first["battleUrl"]).to eq(game_2.battle_url)
      expect(games.second["battleUrl"]).to eq(game_1.battle_url)
    end
  end
end
