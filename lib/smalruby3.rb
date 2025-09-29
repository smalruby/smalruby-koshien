module Smalruby3
end

require_relative "smalruby3/world"
require_relative "smalruby3/sprite"
require_relative "smalruby3/stage"
require_relative "smalruby3/koshien"

include Smalruby3 # standard:disable Style/MixinUsage

# Initialize JSON communication (default behavior)
# Only disable if explicitly set to false
# Skip initialization during tests to avoid circular dependencies
unless ENV["RAILS_ENV"] == "test" || ENV["RSPEC_CORE_RUNNER"] == "1"
  if ENV["KOSHIEN_JSON_MODE"] != "false"
    # Setup JSON communication using main Koshien class
    # This ensures JSON communication is set up before any script execution
    koshien_instance = Smalruby3::Koshien.instance
    if koshien_instance.respond_to?(:setup_json_communication)
      if koshien_instance.setup_json_communication
        # Set up at_exit hook to run the game loop after script execution
        at_exit do
          koshien_instance.run_game_loop
        end
      end
    end
  end
end
