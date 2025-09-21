module Types
  class GameStatusEnum < Types::BaseEnum
    value "WAITING_FOR_PLAYERS", value: "waiting_for_players"
    value "IN_PROGRESS", value: "in_progress"
    value "COMPLETED", value: "completed"
    value "CANCELLED", value: "cancelled"
  end
end