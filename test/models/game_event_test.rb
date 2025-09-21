require "test_helper"

class GameEventTest < ActiveSupport::TestCase
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
    @game_turn = GameTurn.create!(
      game_round: @game_round,
      turn_number: 1,
      turn_finished: false
    )
    @game_event = GameEvent.new(
      game_turn: @game_turn,
      event_type: GameEvent::PLAYER_MOVE,
      event_data: {player_id: 1, from: [0, 0], to: [1, 0]}
    )
  end

  test "should be valid with valid attributes" do
    assert @game_event.valid?
  end

  test "should require game_turn" do
    @game_event.game_turn = nil
    assert_not @game_event.valid?
    assert_includes @game_event.errors[:game_turn], "must exist"
  end

  test "should require event_type" do
    @game_event.event_type = nil
    assert_not @game_event.valid?
    assert_includes @game_event.errors[:event_type], "can't be blank"
  end

  test "should require event_data" do
    @game_event.event_data = nil
    assert_not @game_event.valid?
    assert_includes @game_event.errors[:event_data], "can't be blank"
  end

  test "should validate event_type inclusion" do
    @game_event.event_type = "invalid_type"
    assert_not @game_event.valid?
    assert_includes @game_event.errors[:event_type], "is not included in the list"
  end

  test "should accept valid event types" do
    GameEvent::EVENT_TYPES.each do |event_type|
      @game_event.event_type = event_type
      assert @game_event.valid?, "#{event_type} should be valid"
    end
  end

  test "should serialize event_data as JSON" do
    @game_event.save!
    @game_event.reload
    assert_equal({"player_id" => 1, "from" => [0, 0], "to" => [1, 0]}, @game_event.event_data)
  end

  test "by_type scope should filter by event type" do
    @game_event.save!

    item_event = GameEvent.create!(
      game_turn: @game_turn,
      event_type: GameEvent::ITEM_COLLECT,
      event_data: {player_id: 1, item_type: "coin"}
    )

    move_events = GameEvent.by_type(GameEvent::PLAYER_MOVE)
    item_events = GameEvent.by_type(GameEvent::ITEM_COLLECT)

    assert_includes move_events, @game_event
    assert_not_includes move_events, item_event
    assert_includes item_events, item_event
    assert_not_includes item_events, @game_event
  end

  test "ordered scope should order by turn number and created_at" do
    # Create another turn for ordering test
    later_turn = GameTurn.create!(
      game_round: @game_round,
      turn_number: 2,
      turn_finished: false
    )

    @game_event.save!

    event_2 = GameEvent.create!(
      game_turn: later_turn,
      event_type: GameEvent::ITEM_COLLECT,
      event_data: {player_id: 2, item_type: "gem"}
    )

    event_1_later = GameEvent.create!(
      game_turn: @game_turn,
      event_type: GameEvent::ENEMY_ENCOUNTER,
      event_data: {player_id: 1, enemy_id: 1}
    )

    ordered_events = GameEvent.ordered
    assert_equal [@game_event, event_1_later, event_2], ordered_events.to_a
  end

  test "should define event type constants" do
    assert_equal "player_move", GameEvent::PLAYER_MOVE
    assert_equal "item_collect", GameEvent::ITEM_COLLECT
    assert_equal "enemy_encounter", GameEvent::ENEMY_ENCOUNTER
    assert_equal "game_end", GameEvent::GAME_END
  end

  test "EVENT_TYPES should include all defined constants" do
    expected_types = [
      GameEvent::PLAYER_MOVE,
      GameEvent::ITEM_COLLECT,
      GameEvent::ENEMY_ENCOUNTER,
      GameEvent::GAME_END
    ]
    assert_equal expected_types, GameEvent::EVENT_TYPES
  end
end
