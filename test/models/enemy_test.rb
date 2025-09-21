require "test_helper"

class EnemyTest < ActiveSupport::TestCase
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
    @enemy = Enemy.new(
      game_round: @game_round,
      position_x: 5,
      position_y: 5,
      hp: 100,
      attack_power: 20
    )
  end

  test "should be valid with valid attributes" do
    assert @enemy.valid?
  end

  test "should require game_round" do
    @enemy.game_round = nil
    assert_not @enemy.valid?
    assert_includes @enemy.errors[:game_round], "must exist"
  end

  test "should require position_x" do
    @enemy.position_x = nil
    assert_not @enemy.valid?
    assert_includes @enemy.errors[:position_x], "can't be blank"
  end

  test "should require non-negative position_x" do
    @enemy.position_x = -1
    assert_not @enemy.valid?
    assert_includes @enemy.errors[:position_x], "must be greater than or equal to 0"
  end

  test "should require position_y" do
    @enemy.position_y = nil
    assert_not @enemy.valid?
    assert_includes @enemy.errors[:position_y], "can't be blank"
  end

  test "should require non-negative position_y" do
    @enemy.position_y = -1
    assert_not @enemy.valid?
    assert_includes @enemy.errors[:position_y], "must be greater than or equal to 0"
  end

  test "should require hp" do
    @enemy.hp = nil
    assert_not @enemy.valid?
    assert_includes @enemy.errors[:hp], "can't be blank"
  end

  test "should require non-negative hp" do
    @enemy.hp = -1
    assert_not @enemy.valid?
    assert_includes @enemy.errors[:hp], "must be greater than or equal to 0"
  end

  test "should require attack_power" do
    @enemy.attack_power = nil
    assert_not @enemy.valid?
    assert_includes @enemy.errors[:attack_power], "can't be blank"
  end

  test "should require non-negative attack_power" do
    @enemy.attack_power = -1
    assert_not @enemy.valid?
    assert_includes @enemy.errors[:attack_power], "must be greater than or equal to 0"
  end

  test "position method should return hash with x and y" do
    expected_position = {x: 5, y: 5}
    assert_equal expected_position, @enemy.position
  end

  test "alive? should return true when hp is greater than 0" do
    @enemy.hp = 50
    assert @enemy.alive?
  end

  test "alive? should return false when hp is 0" do
    @enemy.hp = 0
    assert_not @enemy.alive?
  end

  test "alive? should return false when hp is negative" do
    @enemy.hp = -10
    assert_not @enemy.alive?
  end

  test "defeated? should return false when hp is greater than 0" do
    @enemy.hp = 50
    assert_not @enemy.defeated?
  end

  test "defeated? should return true when hp is 0" do
    @enemy.hp = 0
    assert @enemy.defeated?
  end

  test "defeated? should return true when hp is negative" do
    @enemy.hp = -10
    assert @enemy.defeated?
  end

  test "alive? and defeated? should be opposites" do
    @enemy.hp = 50
    assert_equal @enemy.alive?, !@enemy.defeated?

    @enemy.hp = 0
    assert_equal @enemy.alive?, !@enemy.defeated?
  end
end
