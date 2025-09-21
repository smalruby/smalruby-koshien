FactoryBot.define do
  factory :game do
    association :first_player_ai, factory: :player_ai
    association :second_player_ai, factory: :player_ai
    association :game_map
    battle_url { "https://test.example.com/battle/#{rand(1000)}" }
    status { :waiting_for_players }
    winner { nil }
    completed_at { nil }

    trait :in_progress do
      status { :in_progress }
    end

    trait :completed do
      status { :completed }
      winner { :first }
      completed_at { Time.current }
    end

    trait :cancelled do
      status { :cancelled }
    end

    trait :with_first_winner do
      status { :completed }
      winner { :first }
      completed_at { Time.current }
    end

    trait :with_second_winner do
      status { :completed }
      winner { :second }
      completed_at { Time.current }
    end
  end
end
