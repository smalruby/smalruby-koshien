require "test_helper"

class PlayerTest < ActiveSupport::TestCase
  def setup
    @game_map = game_maps(:one)
    @player_ai_1 = player_ais(:one)
    @player_ai_2 = player_ais(:two)
    @game = Game.create!(
      first_player_ai: @player_ai_1,
      second_player_ai: @player_ai_2,
      game_map: @game_map,
      battle_url: "https://test.example.com/battle/1"
    )
    @game_round = GameRound.create!(
      game: @game,
      round_number: 1,
      status: :preparing,
      item_locations: {}
    )
    @player = Player.new(
      game_round: @game_round,
      player_ai: @player_ai_1,
      position_x: 3,
      position_y: 4,
      score: 50,
      dynamite_left: 2,
      character_level: 1
    )
  end

  test "should be valid with valid attributes" do
    assert @player.valid?
  end

  test "should require game_round" do
    @player.game_round = nil
    assert_not @player.valid?
    assert_includes @player.errors[:game_round], "must exist"
  end

  test "should require player_ai" do
    @player.player_ai = nil
    assert_not @player.valid?
    assert_includes @player.errors[:player_ai], "must exist"
  end

  test "should require position_x" do
    @player.position_x = nil
    assert_not @player.valid?
    assert_includes @player.errors[:position_x], "can't be blank"
  end

  test "should require non-negative position_x" do
    @player.position_x = -1
    assert_not @player.valid?
    assert_includes @player.errors[:position_x], "must be greater than or equal to 0"
  end

  test "should require position_y" do
    @player.position_y = nil
    assert_not @player.valid?
    assert_includes @player.errors[:position_y], "can't be blank"
  end

  test "should require non-negative position_y" do
    @player.position_y = -1
    assert_not @player.valid?
    assert_includes @player.errors[:position_y], "must be greater than or equal to 0"
  end

  test "should require score" do
    @player.score = nil
    assert_not @player.valid?
    assert_includes @player.errors[:score], "can't be blank"
  end

  test "should require non-negative score" do
    @player.score = -1
    assert_not @player.valid?
    assert_includes @player.errors[:score], "must be greater than or equal to 0"
  end

  test "should require dynamite_left" do
    @player.dynamite_left = nil
    assert_not @player.valid?
    assert_includes @player.errors[:dynamite_left], "can't be blank"
  end

  test "should require non-negative dynamite_left" do
    @player.dynamite_left = -1
    assert_not @player.valid?
    assert_includes @player.errors[:dynamite_left], "must be greater than or equal to 0"
  end

  test "should require character_level" do
    @player.character_level = nil
    assert_not @player.valid?
    assert_includes @player.errors[:character_level], "can't be blank"
  end

  test "should require character_level to be at least 1" do
    @player.character_level = 0
    assert_not @player.valid?
    assert_includes @player.errors[:character_level], "must be greater than or equal to 1"
  end

  test "status enum should work correctly" do
    @player.status = :active
    assert @player.active?

    @player.status = :inactive
    assert @player.inactive?

    @player.status = :defeated
    assert @player.defeated?
  end

  test "position method should return array with x and y" do
    expected_position = [3, 4]
    assert_equal expected_position, @player.position
  end

  test "previous_position method should return array with previous x and y" do
    @player.previous_position_x = 1
    @player.previous_position_y = 2
    expected_position = [1, 2]
    assert_equal expected_position, @player.previous_position
  end

  test "move_to should update position and store previous position" do
    @player.move_to(5, 6)

    assert_equal 5, @player.position_x
    assert_equal 6, @player.position_y
    assert_equal 3, @player.previous_position_x
    assert_equal 4, @player.previous_position_y
  end

  test "has_moved? should return true when position changed" do
    @player.move_to(5, 6)
    assert @player.has_moved?
  end

  test "has_moved? should return false when position hasn't changed" do
    @player.move_to(3, 4)
    assert_not @player.has_moved?
  end

  test "can_use_dynamite? should return true when dynamite_left > 0" do
    @player.dynamite_left = 2
    assert @player.can_use_dynamite?
  end

  test "can_use_dynamite? should return false when dynamite_left is 0" do
    @player.dynamite_left = 0
    assert_not @player.can_use_dynamite?
  end

  test "use_dynamite should decrease dynamite_left and return true when available" do
    @player.dynamite_left = 2
    result = @player.use_dynamite

    assert result
    assert_equal 1, @player.dynamite_left
  end

  test "use_dynamite should return false when no dynamite left" do
    @player.dynamite_left = 0
    result = @player.use_dynamite

    assert_not result
    assert_equal 0, @player.dynamite_left
  end

  test "apply_goal_bonus should add 100 to score and set has_goal_bonus" do
    @player.has_goal_bonus = false
    @player.score = 50
    result = @player.apply_goal_bonus

    assert result
    assert_equal 150, @player.score
    assert @player.has_goal_bonus?
  end

  test "apply_goal_bonus should return false if already has goal bonus" do
    @player.has_goal_bonus = true
    @player.score = 50
    result = @player.apply_goal_bonus

    assert_not result
    assert_equal 50, @player.score
  end

  test "apply_walk_bonus should add 1 to score and set walk_bonus when moved" do
    @player.walk_bonus = false
    @player.score = 50
    @player.move_to(5, 6)
    result = @player.apply_walk_bonus

    assert result
    assert_equal 51, @player.score
    assert @player.walk_bonus?
  end

  test "apply_walk_bonus should return false if already has walk bonus" do
    @player.walk_bonus = true
    @player.score = 50
    @player.move_to(5, 6)
    result = @player.apply_walk_bonus

    assert_not result
    assert_equal 50, @player.score
  end

  test "apply_walk_bonus should return false if hasn't moved" do
    @player.walk_bonus = false
    @player.score = 50
    # Set previous position to current position to simulate no movement
    @player.previous_position_x = @player.position_x
    @player.previous_position_y = @player.position_y
    result = @player.apply_walk_bonus

    assert_not result
    assert_equal 50, @player.score
    assert_not @player.walk_bonus?
  end

  test "active_players scope should return only active players" do
    @player.status = :active
    @player.save!

    inactive_player = Player.create!(
      game_round: @game_round,
      player_ai: @player_ai_2,
      position_x: 0,
      position_y: 0,
      score: 0,
      dynamite_left: 3,
      character_level: 1,
      status: :inactive
    )

    active_players = Player.active_players

    assert_includes active_players, @player
    assert_not_includes active_players, inactive_player
  end

  test "by_position scope should filter by position" do
    @player.save!

    different_position_player = Player.create!(
      game_round: @game_round,
      player_ai: @player_ai_2,
      position_x: 5,
      position_y: 5,
      score: 0,
      dynamite_left: 3,
      character_level: 1
    )

    players_at_3_4 = Player.by_position(3, 4)
    players_at_5_5 = Player.by_position(5, 5)

    assert_includes players_at_3_4, @player
    assert_not_includes players_at_3_4, different_position_player
    assert_includes players_at_5_5, different_position_player
    assert_not_includes players_at_5_5, @player
  end
end
