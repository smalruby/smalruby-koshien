module Smalruby3
end

require_relative "smalruby3/world"
require_relative "smalruby3/sprite"
require_relative "smalruby3/stage"
require_relative "smalruby3/koshien"
require_relative "smalruby3/koshien_json_adapter"

include Smalruby3 # standard:disable Style/MixinUsage

# Initialize JSON communication when explicitly enabled
if ENV["KOSHIEN_JSON_MODE"] == "true"
  # Setup JSON communication adapter
  at_exit do
    # This ensures JSON communication is properly handled when the script ends
    if defined?(Smalruby3::KoshienJsonAdapter)
      adapter = Smalruby3::KoshienJsonAdapter.instance
      if adapter.respond_to?(:setup_json_communication)
        adapter.setup_json_communication
        adapter.run_game_loop
      end
    end
  end
end
