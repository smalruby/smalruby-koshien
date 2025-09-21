FactoryBot.define do
  factory :game_round do
    association :game
    sequence(:round_number) { |n| n }
    status { :preparing }
    item_locations { {} }
    winner { nil }

    trait :in_progress do
      status { :in_progress }
    end

    trait :finished do
      status { :finished }
      winner { :first }
    end

    trait :with_items do
      item_locations { {"0,0" => "power_up", "1,1" => "dynamite"} }
    end
  end
end