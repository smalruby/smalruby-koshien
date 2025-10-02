FactoryBot.define do
  factory :player_snapshot do
    association :game_turn
    association :player
    position_x { 0 }
    position_y { 0 }
    previous_position_x { 0 }
    previous_position_y { 0 }
    score { 0 }
    status { :playing }
    has_goal_bonus { false }
    in_water { false }
    movable { true }
    dynamite_left { 3 }
    character_level { 1 }
    walk_bonus { false }
    bomb_left { 2 }
    walk_bonus_counter { 0 }
    acquired_positive_items { [0, 0, 0, 0, 0, 0] }
    my_map { Array.new(17) { Array.new(17, -1) } }
    map_fov { Array.new(17) { Array.new(17, -1) } }

    trait :with_score do
      score { 100 }
    end

    trait :at_position do
      transient do
        x { 5 }
        y { 10 }
      end

      position_x { x }
      position_y { y }
    end

    trait :with_items do
      acquired_positive_items { [0, 1, 2, 3, 0, 0] }
    end

    trait :high_level do
      character_level { 5 }
      score { 100 }
    end

    trait :timeout do
      status { :timeout }
    end

    trait :completed do
      status { :completed }
    end
  end
end
