require "test_helper"

class GameRoundTest < ActiveSupport::TestCase
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
    @game_round = GameRound.new(
      game: @game,
      round_number: 1,
      status: :preparing,
      item_locations: {"1,1" => "coin", "5,5" => "gem"}
    )
  end

  test "should be valid with valid attributes" do
    assert @game_round.valid?
  end

  test "should require game" do
    @game_round.game = nil
    assert_not @game_round.valid?
    assert_includes @game_round.errors[:game], "must exist"
  end

  test "should require round_number" do
    @game_round.round_number = nil
    assert_not @game_round.valid?
    assert_includes @game_round.errors[:round_number], "can't be blank"
  end

  test "should require status" do
    @game_round.status = nil
    assert_not @game_round.valid?
    assert_includes @game_round.errors[:status], "can't be blank"
  end

  test "should require item_locations" do
    @game_round.item_locations = nil
    assert_not @game_round.valid?
    assert_includes @game_round.errors[:item_locations], "can't be blank"
  end

  test "should validate uniqueness of round_number scoped to game" do
    @game_round.save!

    duplicate_round = GameRound.new(
      game: @game,
      round_number: 1,
      status: :preparing,
      item_locations: {}
    )

    assert_not duplicate_round.valid?
    assert_includes duplicate_round.errors[:round_number], "has already been taken"
  end

  test "should allow same round_number for different games" do
    @game_round.save!

    another_game = Game.create!(
      first_player_ai: @player_ai_1,
      second_player_ai: @player_ai_2,
      game_map: @game_map,
      battle_url: "https://test.example.com/battle/2"
    )

    another_round = GameRound.new(
      game: another_game,
      round_number: 1,
      status: :preparing,
      item_locations: {}
    )

    assert another_round.valid?
  end

  test "should have many players with dependent destroy" do
    @game_round.save!
    player = Player.create!(
      game_round: @game_round,
      player_ai: @player_ai_1,
      position_x: 0,
      position_y: 0,
      score: 0,
      dynamite_left: 3,
      character_level: 1
    )

    assert_includes @game_round.players, player

    assert_difference "Player.count", -1 do
      @game_round.destroy
    end
  end

  test "should have many enemies with dependent destroy" do
    @game_round.save!
    enemy = Enemy.create!(
      game_round: @game_round,
      position_x: 5,
      position_y: 5,
      hp: 100,
      attack_power: 20
    )

    assert_includes @game_round.enemies, enemy

    assert_difference "Enemy.count", -1 do
      @game_round.destroy
    end
  end

  test "should have many game_turns with dependent destroy" do
    @game_round.save!
    game_turn = GameTurn.create!(
      game_round: @game_round,
      turn_number: 1,
      turn_finished: false
    )

    assert_includes @game_round.game_turns, game_turn

    assert_difference "GameTurn.count", -1 do
      @game_round.destroy
    end
  end

  test "status enum should work correctly" do
    @game_round.status = :preparing
    assert @game_round.preparing?

    @game_round.status = :in_progress
    assert @game_round.in_progress?

    @game_round.status = :finished
    assert @game_round.finished?
  end

  test "winner enum should work correctly" do
    @game_round.winner = :no_winner
    assert @game_round.no_winner?

    @game_round.winner = :player1
    assert @game_round.player1?

    @game_round.winner = :player2
    assert @game_round.player2?

    @game_round.winner = :draw
    assert @game_round.draw?
  end

  test "by_round_number scope should filter by round number" do
    @game_round.save!

    round_2 = GameRound.create!(
      game: @game,
      round_number: 2,
      status: :preparing,
      item_locations: {}
    )

    round_1_results = GameRound.by_round_number(1)
    round_2_results = GameRound.by_round_number(2)

    assert_includes round_1_results, @game_round
    assert_not_includes round_1_results, round_2
    assert_includes round_2_results, round_2
    assert_not_includes round_2_results, @game_round
  end

  test "finished_rounds scope should return only finished rounds" do
    @game_round.save!

    finished_round = GameRound.create!(
      game: @game,
      round_number: 2,
      status: :finished,
      item_locations: {}
    )

    finished_rounds = GameRound.finished_rounds

    assert_includes finished_rounds, finished_round
    assert_not_includes finished_rounds, @game_round
  end
end
