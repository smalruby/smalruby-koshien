require "rails_helper"

RSpec.describe PlayerSnapshot, type: :model do
  let(:game) { create(:game) }
  let(:game_round) { create(:game_round, game: game) }
  let(:game_turn) { create(:game_turn, game_round: game_round, turn_number: 1) }
  let(:player) { create(:player, game_round: game_round) }

  describe "associations" do
    it "belongs to game_turn" do
      snapshot = build(:player_snapshot, game_turn: game_turn, player: player)
      expect(snapshot.game_turn).to eq(game_turn)
    end

    it "belongs to player" do
      snapshot = build(:player_snapshot, game_turn: game_turn, player: player)
      expect(snapshot.player).to eq(player)
    end
  end

  describe "validations" do
    it "validates presence of required fields" do
      snapshot = PlayerSnapshot.new
      expect(snapshot).not_to be_valid
      expect(snapshot.errors[:position_x]).to include("can't be blank")
      expect(snapshot.errors[:position_y]).to include("can't be blank")
      expect(snapshot.errors[:score]).to include("can't be blank")
    end

    it "validates numericality of position fields" do
      snapshot = build(:player_snapshot, position_x: -1)
      expect(snapshot).not_to be_valid
      expect(snapshot.errors[:position_x]).to include("must be greater than or equal to 0")
    end
  end

  describe "serialization" do
    it "serializes my_map as JSON" do
      snapshot = create(:player_snapshot, game_turn: game_turn, player: player)
      expect(snapshot.my_map).to be_a(Array)
    end

    it "serializes map_fov as JSON" do
      snapshot = create(:player_snapshot, game_turn: game_turn, player: player)
      expect(snapshot.map_fov).to be_a(Array)
    end
  end

  describe "enum" do
    it "defines status enum" do
      snapshot = build(:player_snapshot)
      expect(snapshot).to respond_to(:playing?)
      expect(snapshot).to respond_to(:completed?)
      expect(snapshot).to respond_to(:timeout?)
      expect(snapshot).to respond_to(:timeup?)
    end
  end

  describe "#position" do
    it "returns position as array" do
      snapshot = build(:player_snapshot, position_x: 5, position_y: 10)
      expect(snapshot.position).to eq([5, 10])
    end
  end

  describe "#previous_position" do
    it "returns previous position as array" do
      snapshot = build(:player_snapshot, previous_position_x: 3, previous_position_y: 7)
      expect(snapshot.previous_position).to eq([3, 7])
    end
  end

  describe "snapshot creation" do
    it "creates a snapshot with all player attributes" do
      snapshot = create(:player_snapshot,
        game_turn: game_turn,
        player: player,
        position_x: 5,
        position_y: 10,
        score: 100,
        character_level: 3,
        dynamite_left: 2,
        bomb_left: 1,
        walk_bonus_counter: 5,
        acquired_positive_items: [0, 1, 2, 3, 0, 0])

      expect(snapshot.position_x).to eq(5)
      expect(snapshot.position_y).to eq(10)
      expect(snapshot.score).to eq(100)
      expect(snapshot.character_level).to eq(3)
      expect(snapshot.dynamite_left).to eq(2)
      expect(snapshot.bomb_left).to eq(1)
      expect(snapshot.walk_bonus_counter).to eq(5)
      expect(snapshot.acquired_positive_items).to eq([0, 1, 2, 3, 0, 0])
    end
  end

  describe "unique constraint" do
    it "allows only one snapshot per game_turn and player" do
      create(:player_snapshot, game_turn: game_turn, player: player)

      duplicate = build(:player_snapshot, game_turn: game_turn, player: player)
      expect { duplicate.save! }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "allows multiple snapshots for same player in different turns" do
      turn1 = create(:game_turn, game_round: game_round, turn_number: 1)
      turn2 = create(:game_turn, game_round: game_round, turn_number: 2)

      snapshot1 = create(:player_snapshot, game_turn: turn1, player: player)
      snapshot2 = create(:player_snapshot, game_turn: turn2, player: player)

      expect(snapshot1).to be_persisted
      expect(snapshot2).to be_persisted
    end
  end
end
