FactoryBot.define do
  factory :enemy do
    association :game_round
    position_x { 1 }
    position_y { 1 }
    hp { 100 }
    attack_power { 10 }

    trait :weak do
      hp { 1 }
      attack_power { 1 }
    end

    trait :strong do
      hp { 200 }
      attack_power { 25 }
    end

    trait :defeated do
      hp { 0 }
    end

    trait :at_position do
      transient do
        x { 3 }
        y { 4 }
      end

      position_x { x }
      position_y { y }
    end
  end
end
