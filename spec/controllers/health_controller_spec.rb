# frozen_string_literal: true

require "rails_helper"

RSpec.describe HealthController, type: :controller do
  describe "GET #show" do
    it "returns successful health check response" do
      get :show

      expect(response).to have_http_status(:success)
    end

    it "returns JSON with status ok" do
      get :show

      json_response = JSON.parse(response.body)
      expect(json_response["status"]).to eq("ok")
    end

    it "includes timestamp in response" do
      get :show

      json_response = JSON.parse(response.body)
      expect(json_response["timestamp"]).to be_present
      expect { Time.iso8601(json_response["timestamp"]) }.not_to raise_error
    end

    it "includes Rails version in response" do
      get :show

      json_response = JSON.parse(response.body)
      expect(json_response["version"]).to eq(Rails.version)
    end

    it "includes environment in response" do
      get :show

      json_response = JSON.parse(response.body)
      expect(json_response["environment"]).to eq(Rails.env)
    end
  end
end
