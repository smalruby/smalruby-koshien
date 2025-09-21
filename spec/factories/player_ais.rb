FactoryBot.define do
  factory :player_ai do
    sequence(:name) { |n| "Test AI #{n}" }
    code { "puts 'Hello World'" }
    author { "test_user" }
    expires_at { 2.days.from_now }

    trait :preset do
      author { "system" }
      expires_at { 1.year.from_now }
    end

    trait :expired do
      expires_at { 1.day.ago }
    end

    trait :with_ruby_code do
      code { "player.move(:up)" }
    end
  end
end
