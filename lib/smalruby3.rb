module Smalruby3
end

require_relative "smalruby3/world"
require_relative "smalruby3/sprite"
require_relative "smalruby3/stage"
require_relative "smalruby3/koshien"
require_relative "smalruby3/koshien_json_adapter"

include Smalruby3 # standard:disable Style/MixinUsage

# Initialize JSON communication (default behavior)
# Only disable if explicitly set to false
if ENV["KOSHIEN_JSON_MODE"] != "false"
  # Setup JSON communication adapter immediately
  # This ensures JSON communication is set up before any script execution
  if defined?(Smalruby3::KoshienJsonAdapter)
    adapter = Smalruby3::KoshienJsonAdapter.instance
    if adapter.respond_to?(:setup_json_communication)
      if adapter.setup_json_communication
        # Set up at_exit hook to run the game loop after script execution
        at_exit do
          adapter.run_game_loop
        end
      end
    end
  end
end
