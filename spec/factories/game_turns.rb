FactoryBot.define do
  factory :game_turn do
    association :game_round
    sequence(:turn_number) { |n| n }
    turn_finished { false }

    trait :finished do
      turn_finished { true }
    end

    trait :with_events do
      after(:create) do |game_turn|
        create(:game_event, game_turn: game_turn)
      end
    end
  end
end
