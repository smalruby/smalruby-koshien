module Smalruby3
end

require_relative "smalruby3/world"
require_relative "smalruby3/sprite"
require_relative "smalruby3/stage"
require_relative "smalruby3/koshien"
require_relative "smalruby3/koshien_json_adapter"

include Smalruby3 # standard:disable Style/MixinUsage

# Initialize JSON communication (required - traditional mode removed)
# JSON mode is now the only supported mode
# Skip initialization in test environment to avoid setup failures
unless Rails.env.test?
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
