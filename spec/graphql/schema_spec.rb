require "rails_helper"

RSpec.describe SmalrubyKoshienSchema, type: :request do
  describe "Schema validation" do
    it "スキーマが有効である" do
      expect { SmalrubyKoshienSchema.to_definition }.not_to raise_error
    end

    it "スキーマが基本的なクエリタイプを持つ" do
      expect(SmalrubyKoshienSchema.query).to eq(Types::QueryType)
    end

    it "スキーマが基本的なミューテーションタイプを持つ" do
      expect(SmalrubyKoshienSchema.mutation).to eq(Types::MutationType)
    end

    it "DataLoaderが設定されている" do
      plugin_classes = SmalrubyKoshienSchema.plugins.map(&:first)
      expect(plugin_classes).to include(GraphQL::Dataloader)
    end
  end

  describe "エラーハンドリング" do
    let(:invalid_query) do
      <<~GRAPHQL
        query {
          nonExistentField
        }
      GRAPHQL
    end

    it "存在しないフィールドでエラーを返す" do
      post "/graphql", params: {query: invalid_query}

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json["errors"]).to be_present
      expect(json["errors"].first["message"]).to include("Field 'nonExistentField' doesn't exist")
    end
  end

  describe "基本的なクエリ実行" do
    let(:introspection_query) do
      <<~GRAPHQL
        query {
          __schema {
            types {
              name
            }
          }
        }
      GRAPHQL
    end

    it "Introspectionクエリが実行できる" do
      post "/graphql", params: {query: introspection_query}

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json["data"]["__schema"]["types"]).to be_present
      type_names = json["data"]["__schema"]["types"].map { |type| type["name"] }
      expect(type_names).to include("PlayerAi", "GameMap", "Query", "Mutation")
    end
  end

  describe "GlobalID 機能" do
    let!(:player_ai) { create(:player_ai) }

    let(:node_query) do
      <<~GRAPHQL
        query($id: ID!) {
          node(id: $id) {
            __typename
            ... on PlayerAi {
              name
            }
          }
        }
      GRAPHQL
    end

    it "GlobalIDでオブジェクトを取得できる" do
      global_id = player_ai.to_gid_param
      variables = {id: global_id}

      post "/graphql", params: {query: node_query, variables: variables.to_json}

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      if json["errors"]
        puts "GraphQL Errors: #{json["errors"]}"
      end

      expect(json["data"]).to be_present
      expect(json["data"]["node"]).to be_present
      expect(json["data"]["node"]["__typename"]).to eq("PlayerAi")
      expect(json["data"]["node"]["name"]).to eq(player_ai.name)
    end
  end
end
