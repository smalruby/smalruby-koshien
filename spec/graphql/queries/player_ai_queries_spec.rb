require "rails_helper"

RSpec.describe "PlayerAi Queries", type: :request do
  let!(:preset_ai_1) { create(:player_ai, :preset) }
  let!(:preset_ai_2) { create(:player_ai, :preset) }
  let!(:user_ai_1) { create(:player_ai, author: "testuser") }
  let!(:expired_ai) { create(:player_ai, :expired) }

  describe "availablePlayerAis query" do
    let(:query) do
      <<~GRAPHQL
        query {
          availablePlayerAis {
            name
            author
            expired
            preset
          }
        }
      GRAPHQL
    end

    it "期限切れでないPlayerAIのみを返す" do
      post "/graphql", params: {query: query}

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json["data"]["availablePlayerAis"]).to be_present
      ai_names = json["data"]["availablePlayerAis"].map { |ai| ai["name"] }

      expect(ai_names).to include(preset_ai_1.name, preset_ai_2.name, user_ai_1.name)
      expect(ai_names).not_to include(expired_ai.name)
    end

    it "各PlayerAIの属性が正しく返される" do
      post "/graphql", params: {query: query}

      json = JSON.parse(response.body)
      preset_ai_data = json["data"]["availablePlayerAis"].find { |ai| ai["name"] == preset_ai_1.name }

      expect(preset_ai_data["author"]).to eq("system")
      expect(preset_ai_data["expired"]).to be false
      expect(preset_ai_data["preset"]).to be true
    end
  end

  describe "presetPlayerAis query" do
    let(:query) do
      <<~GRAPHQL
        query {
          presetPlayerAis {
            name
            author
            preset
          }
        }
      GRAPHQL
    end

    it "プリセットPlayerAIのみを返す" do
      post "/graphql", params: {query: query}

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json["data"]["presetPlayerAis"]).to be_present
      ai_names = json["data"]["presetPlayerAis"].map { |ai| ai["name"] }

      expect(ai_names).to include(preset_ai_1.name, preset_ai_2.name)
      expect(ai_names).not_to include(user_ai_1.name, expired_ai.name)
    end

    it "全てのPlayerAIがpresetである" do
      post "/graphql", params: {query: query}

      json = JSON.parse(response.body)
      json["data"]["presetPlayerAis"].each do |ai|
        expect(ai["preset"]).to be true
        expect(ai["author"]).to eq("system")
      end
    end
  end
end
