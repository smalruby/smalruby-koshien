FactoryBot.define do
  factory :game_map do
    sequence(:name) { |n| "Test Map #{n}" }
    description { "Test map for development" }
    map_data { [[0, 0, 0, 0, 0], [0, 1, 0, 1, 0], [0, 0, 0, 0, 0]] }
    map_height { [[0, 0, 0, 0, 0], [0, 0, 0, 0, 0], [0, 0, 0, 0, 0]] }
    goal_position { {"x" => 4, "y" => 2} }

    trait :simple_map do
      name { "Simple Map" }
      map_data { [[0, 0, 0]] }
      goal_position { {"x" => 1, "y" => 1} }
    end

    trait :complex_map do
      name { "Complex Map" }
      map_data { [[1, 1, 1], [1, 0, 1], [1, 1, 1]] }
      goal_position { {"x" => 1, "y" => 1} }
    end
  end
end
