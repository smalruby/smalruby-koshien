class HealthController < ApplicationController
  def show
    render json: {
      status: "ok",
      timestamp: Time.current.iso8601,
      version: Rails.version,
      environment: Rails.env
    }
  end
end