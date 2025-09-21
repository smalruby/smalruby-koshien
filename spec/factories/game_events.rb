FactoryBot.define do
  factory :game_event do
    association :game_turn
    event_type { GameEvent::PLAYER_MOVE }
    event_data { {player_id: 1, from: [0, 0], to: [1, 0]} }

    trait :player_move do
      event_type { GameEvent::PLAYER_MOVE }
      event_data { {player_id: 1, from: [0, 0], to: [1, 0]} }
    end

    trait :player_attack do
      event_type { GameEvent::PLAYER_ATTACK }
      event_data { {player_id: 1, target_id: 2, damage: 10} }
    end

    trait :item_pickup do
      event_type { GameEvent::ITEM_PICKUP }
      event_data { {player_id: 1, item_type: "power_up", position: [1, 1]} }
    end

    trait :round_start do
      event_type { GameEvent::ROUND_START }
      event_data { {round_number: 1} }
    end

    trait :round_end do
      event_type { GameEvent::ROUND_END }
      event_data { {round_number: 1, winner: "first"} }
    end
  end
end