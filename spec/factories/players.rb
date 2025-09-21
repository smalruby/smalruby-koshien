FactoryBot.define do
  factory :player do
    association :game_round
    association :player_ai
    position_x { 0 }
    position_y { 0 }
    score { 0 }
    dynamite_left { 3 }
    character_level { 1 }
    status { :active }
    has_goal_bonus { false }
    walk_bonus { false }
    previous_position_x { nil }
    previous_position_y { nil }

    trait :with_score do
      score { 100 }
    end

    trait :with_dynamite do
      dynamite_left { 5 }
    end

    trait :inactive do
      status { :inactive }
    end

    trait :defeated do
      status { :defeated }
    end

    trait :at_position do
      transient do
        x { 2 }
        y { 3 }
      end

      position_x { x }
      position_y { y }
    end

    trait :with_goal_bonus do
      has_goal_bonus { true }
      score { 100 }
    end

    trait :with_walk_bonus do
      walk_bonus { true }
    end
  end
end