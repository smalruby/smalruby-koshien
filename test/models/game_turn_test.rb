require "test_helper"

class GameTurnTest < ActiveSupport::TestCase
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
    @game_turn = GameTurn.new(
      game_round: @game_round,
      turn_number: 1,
      turn_finished: false
    )
  end

  test "should be valid with valid attributes" do
    assert @game_turn.valid?
  end

  test "should require game_round" do
    @game_turn.game_round = nil
    assert_not @game_turn.valid?
    assert_includes @game_turn.errors[:game_round], "must exist"
  end

  test "should require turn_number" do
    @game_turn.turn_number = nil
    assert_not @game_turn.valid?
    assert_includes @game_turn.errors[:turn_number], "can't be blank"
  end

  test "should require positive turn_number" do
    @game_turn.turn_number = 0
    assert_not @game_turn.valid?
    assert_includes @game_turn.errors[:turn_number], "must be greater than 0"
  end

  test "should require turn_finished to be boolean" do
    @game_turn.turn_finished = nil
    assert_not @game_turn.valid?
    assert_includes @game_turn.errors[:turn_finished], "is not included in the list"
  end

  test "should have many game_events" do
    @game_turn.save!
    game_event = GameEvent.create!(
      game_turn: @game_turn,
      event_type: GameEvent::PLAYER_MOVE,
      event_data: {player_id: 1, from: [0, 0], to: [1, 0]}
    )
    assert_includes @game_turn.game_events, game_event
  end

  test "should destroy associated game_events when destroyed" do
    @game_turn.save!
    GameEvent.create!(
      game_turn: @game_turn,
      event_type: GameEvent::PLAYER_MOVE,
      event_data: {player_id: 1, from: [0, 0], to: [1, 0]}
    )

    assert_difference "GameEvent.count", -1 do
      @game_turn.destroy
    end
  end

  test "finished scope should return finished turns" do
    finished_turn = GameTurn.create!(
      game_round: @game_round,
      turn_number: 1,
      turn_finished: true
    )
    unfinished_turn = GameTurn.create!(
      game_round: @game_round,
      turn_number: 2,
      turn_finished: false
    )

    assert_includes GameTurn.finished, finished_turn
    assert_not_includes GameTurn.finished, unfinished_turn
  end

  test "unfinished scope should return unfinished turns" do
    finished_turn = GameTurn.create!(
      game_round: @game_round,
      turn_number: 1,
      turn_finished: true
    )
    unfinished_turn = GameTurn.create!(
      game_round: @game_round,
      turn_number: 2,
      turn_finished: false
    )

    assert_includes GameTurn.unfinished, unfinished_turn
    assert_not_includes GameTurn.unfinished, finished_turn
  end

  test "ordered scope should return turns ordered by turn_number" do
    turn_3 = GameTurn.create!(
      game_round: @game_round,
      turn_number: 3,
      turn_finished: false
    )
    turn_1 = GameTurn.create!(
      game_round: @game_round,
      turn_number: 1,
      turn_finished: false
    )
    turn_2 = GameTurn.create!(
      game_round: @game_round,
      turn_number: 2,
      turn_finished: false
    )

    ordered_turns = GameTurn.ordered
    assert_equal [turn_1, turn_2, turn_3], ordered_turns.to_a
  end
end
