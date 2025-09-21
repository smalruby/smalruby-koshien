require "rails_helper"

RSpec.describe "RegisterPlayerAi Mutation", type: :request do
  describe "registerPlayerAi mutation" do
    let(:valid_mutation) do
      <<~GRAPHQL
        mutation($input: RegisterPlayerAiInput!) {
          registerPlayerAi(input: $input) {
            playerAi {
              name
              code
              author
              expired
              preset
            }
            errors
          }
        }
      GRAPHQL
    end

    context "有効なパラメータの場合" do
      let(:variables) do
        {
          input: {
            name: "テストAI",
            code: "puts 'Hello World'",
            author: "testuser"
          }
        }
      end

      it "PlayerAIを正常に作成する" do
        expect {
          post "/graphql", params: {query: valid_mutation, variables: variables}
        }.to change(PlayerAi, :count).by(1)

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)

        player_ai_data = json["data"]["registerPlayerAi"]["playerAi"]
        expect(player_ai_data["name"]).to eq("テストAI")
        expect(player_ai_data["code"]).to eq("puts 'Hello World'")
        expect(player_ai_data["author"]).to eq("testuser")
        expect(player_ai_data["expired"]).to be false
        expect(player_ai_data["preset"]).to be false

        expect(json["data"]["registerPlayerAi"]["errors"]).to be_empty
      end
    end

    context "authorが省略された場合" do
      let(:variables) do
        {
          input: {
            name: "テストAI",
            code: "puts 'Hello World'"
          }
        }
      end

      it "PlayerAIを正常に作成する" do
        post "/graphql", params: {query: valid_mutation, variables: variables}

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)

        player_ai_data = json["data"]["registerPlayerAi"]["playerAi"]
        expect(player_ai_data["name"]).to eq("テストAI")
        expect(player_ai_data["author"]).to be_nil
      end
    end

    context "無効なパラメータの場合" do
      let(:invalid_variables) do
        {
          input: {
            name: "",
            code: "puts 'Hello World'",
            author: "testuser"
          }
        }
      end

      it "エラーを返し、PlayerAIを作成しない" do
        expect {
          post "/graphql", params: {query: valid_mutation, variables: invalid_variables}
        }.not_to change(PlayerAi, :count)

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)

        expect(json["data"]["registerPlayerAi"]["playerAi"]).to be_nil
        expect(json["data"]["registerPlayerAi"]["errors"]).to be_present
        expect(json["data"]["registerPlayerAi"]["errors"]).to include(match(/can't be blank/i))
      end
    end

    context "重複した名前の場合" do
      let!(:existing_ai) { create(:player_ai, name: "重複AI") }
      let(:duplicate_variables) do
        {
          input: {
            name: "重複AI",
            code: "puts 'Hello World'",
            author: "testuser"
          }
        }
      end

      it "エラーを返し、PlayerAIを作成しない" do
        expect {
          post "/graphql", params: {query: valid_mutation, variables: duplicate_variables}
        }.not_to change(PlayerAi, :count)

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)

        expect(json["data"]["registerPlayerAi"]["playerAi"]).to be_nil
        expect(json["data"]["registerPlayerAi"]["errors"]).to be_present
        expect(json["data"]["registerPlayerAi"]["errors"]).to include(match(/has already been taken/i))
      end
    end
  end
end
