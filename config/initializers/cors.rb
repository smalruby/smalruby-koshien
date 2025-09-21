# IMPORTANT: For S3 direct uploads to work, you must configure the CORS policy on your S3 bucket.
# Go to your S3 bucket -> Permissions -> Cross-origin resource sharing (CORS) and add a configuration like this:
#
# [
#   {
#     "AllowedHeaders": [
#       "*"
#     ],
#     "AllowedMethods": [
#       "PUT"
#     ],
#     "AllowedOrigins": [
#       "https://koshien.smalruby.app",
#       "https://smalruby.app",
#       "https://smalruby.jp",
#       "http://localhost:8601"
#     ],
#     "ExposeHeaders": []
#   }
# ]
#
# Be sure to restart your server when you modify this file.

# Avoid CORS issues when API is called from the frontend app.
# Handle Cross-Origin Resource Sharing (CORS) in order to accept cross-origin Ajax requests.

# Read more: https://github.com/cyu/rack-cors

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins "https://koshien.smalruby.app",
      "https://smalruby.app",
      "https://smalruby.jp",
      "http://localhost:8601"

    resource "*",
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head]
  end
end
