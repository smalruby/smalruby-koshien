require "rails_helper"

RSpec.describe Enemy, type: :model do
  # Test setup for basic model tests
  let(:game_map) { GameMap.create!(name: "Test Map", map_data: [[0, 0, 0], [0, 1, 0], [0, 0, 0]], goal_position: {"x" => 2, "y" => 2}) }
  let(:player_ai_1) { PlayerAi.create!(name: "Test AI 1", code: "test code", author: "test") }
  let(:player_ai_2) { PlayerAi.create!(name: "Test AI 2", code: "test code", author: "test") }
  let(:game) { Game.create!(first_player_ai: player_ai_1, second_player_ai: player_ai_2, game_map: game_map, battle_url: "https://test.example.com/battle/1") }
  let(:game_round) { GameRound.create!(game: game, round_number: 1, status: :preparing, item_locations: {}) }
  let(:enemy) { Enemy.new(game_round: game_round, position_x: 5, position_y: 5) }

  # Test setup for movement logic tests (15x15 blank map)
  let(:blank_map_data) do
    Array.new(15) { Array.new(15, 0) } # 15x15 map with all blank spaces (0)
  end
  let(:blank_game_map) { GameMap.create!(name: "Blank Map", map_data: blank_map_data, goal_position: {"x" => 7, "y" => 7}) }
  let(:blank_game) { Game.create!(first_player_ai: player_ai_1, second_player_ai: player_ai_2, game_map: blank_game_map, battle_url: "https://test.example.com/battle/2") }
  let(:blank_game_round) { GameRound.create!(game: blank_game, round_number: 1, status: :in_progress, item_locations: {}) }

  describe "バリデーション" do
    it "有効な属性で有効である" do
      expect(enemy).to be_valid
    end

    it "game_roundが必須である" do
      enemy.game_round = nil
      expect(enemy).not_to be_valid
      expect(enemy.errors[:game_round]).to include("must exist")
    end

    it "position_xが必須である" do
      enemy.position_x = nil
      expect(enemy).not_to be_valid
      expect(enemy.errors[:position_x]).to include("can't be blank")
    end

    it "position_xが非負数である" do
      enemy.position_x = -1
      expect(enemy).not_to be_valid
      expect(enemy.errors[:position_x]).to include("must be greater than or equal to 0")
    end

    it "position_yが必須である" do
      enemy.position_y = nil
      expect(enemy).not_to be_valid
      expect(enemy.errors[:position_y]).to include("can't be blank")
    end

    it "position_yが非負数である" do
      enemy.position_y = -1
      expect(enemy).not_to be_valid
      expect(enemy.errors[:position_y]).to include("must be greater than or equal to 0")
    end
  end

  describe "#position" do
    it "xとyのハッシュを返す" do
      expected_position = {x: 5, y: 5}
      expect(enemy.position).to eq(expected_position)
    end
  end

  describe "#killed?" do
    it "初期状態ではfalseを返す" do
      expect(enemy.killed?).to be_falsey
    end

    it "killedがtrueの時にtrueを返す" do
      enemy.killed = true
      expect(enemy.killed?).to be_truthy
    end

    it "killedがfalseの時にfalseを返す" do
      enemy.killed = false
      expect(enemy.killed?).to be_falsey
    end
  end

  describe "ステート管理" do
    it "normal?メソッドでnormal_stateを判定できる" do
      enemy.state = :normal_state
      expect(enemy.normal?).to be_truthy
    end

    it "angry?メソッドでangryステートを判定できる" do
      enemy.state = :angry
      expect(enemy.angry?).to be_truthy
    end

    it "kill?メソッドでkillステートを判定できる" do
      enemy.state = :kill
      expect(enemy.kill?).to be_truthy
    end
  end

  describe "#can_attack?" do
    it "both_killの場合にプレイヤー0に対してtrueを返す" do
      enemy.enemy_kill = :both_kill
      expect(enemy.can_attack?(0)).to be_truthy
    end

    it "both_killの場合にプレイヤー1に対してtrueを返す" do
      enemy.enemy_kill = :both_kill
      expect(enemy.can_attack?(1)).to be_truthy
    end

    it "player1_killの場合にプレイヤー0に対してtrueを返す" do
      enemy.enemy_kill = :player1_kill
      expect(enemy.can_attack?(0)).to be_truthy
    end

    it "player1_killの場合にプレイヤー1に対してfalseを返す" do
      enemy.enemy_kill = :player1_kill
      expect(enemy.can_attack?(1)).to be_falsey
    end

    it "player2_killの場合にプレイヤー0に対してfalseを返す" do
      enemy.enemy_kill = :player2_kill
      expect(enemy.can_attack?(0)).to be_falsey
    end

    it "player2_killの場合にプレイヤー1に対してtrueを返す" do
      enemy.enemy_kill = :player2_kill
      expect(enemy.can_attack?(1)).to be_truthy
    end

    it "no_killの場合に両プレイヤーに対してfalseを返す" do
      enemy.enemy_kill = :no_kill
      expect(enemy.can_attack?(0)).to be_falsey
      expect(enemy.can_attack?(1)).to be_falsey
    end
  end

  # Movement logic tests based on reference implementation
  describe "#move" do
    let(:player1) { Player.create!(game_round: blank_game_round, player_ai: player_ai_1, position_x: 6, position_y: 6, previous_position_x: 6, previous_position_y: 6, score: 0, character_level: 1, dynamite_left: 2, bomb_left: 2, walk_bonus_counter: 0, acquired_positive_items: [0, 0, 0, 0, 0, 0], status: :playing) }
    let(:player2) { Player.create!(game_round: blank_game_round, player_ai: player_ai_2, position_x: 13, position_y: 13, previous_position_x: 13, previous_position_y: 13, score: 0, character_level: 1, dynamite_left: 2, bomb_left: 2, walk_bonus_counter: 0, acquired_positive_items: [0, 0, 0, 0, 0, 0], status: :playing) }
    let(:test_enemy) { Enemy.create!(game_round: blank_game_round, position_x: 5, position_y: 5, previous_position_x: 5, previous_position_y: 5, state: :normal_state, enemy_kill: :no_kill) }

    before do
      # Ensure players exist for movement tests
      player1
      player2
    end

    context "プレイヤーが射程内にいるとき" do
      it "プレイヤーに接近すること" do
        # Enemy positions that should move toward player1 at (6,6)
        move_to_player1_positions = [
          [3, 3], [3, 4], [3, 5], [3, 6], [3, 7], [3, 8], [3, 9],
          [4, 3], [4, 4], [4, 5], [4, 7], [4, 8], [4, 9],
          [5, 3], [5, 4], [5, 8], [5, 9],
          [6, 3], [6, 9],
          [7, 3], [7, 4], [7, 8], [7, 9],
          [8, 3], [8, 4], [8, 5], [8, 7], [8, 8], [8, 9],
          [9, 3], [9, 4], [9, 5], [9, 6], [9, 7], [9, 8], [9, 9]
        ]

        move_to_player1_positions.each do |pos|
          test_enemy.update!(position_x: pos[0], position_y: pos[1], previous_position_x: pos[0], previous_position_y: pos[1])

          # Distance to player1 before move
          distance_before = (player1.position_x - test_enemy.position_x).abs + (player1.position_y - test_enemy.position_y).abs

          test_enemy.move(blank_game_map.map_data, [player1, player2], blank_game_round)

          # Distance to player1 after move
          distance_after = (player1.position_x - test_enemy.position_x).abs + (player1.position_y - test_enemy.position_y).abs

          # Should be 1 step closer (or stay if too close)
          expect(distance_after).to be <= distance_before
          if distance_before > 2
            expect(distance_before - distance_after).to eq(1)
          end
        end
      end

      context "プレイヤーのすぐ近くにいるとき" do
        it "その場にとどまること（自分から体当たりはしない）" do
          # Same position and adjacent positions
          [[6, 6], [5, 6], [7, 6], [6, 5], [6, 7]].each do |pos|
            test_enemy.update!(position_x: pos[0], position_y: pos[1], previous_position_x: pos[0], previous_position_y: pos[1])
            original_x, original_y = test_enemy.position_x, test_enemy.position_y

            test_enemy.move(blank_game_map.map_data, [player1, player2], blank_game_round)

            expect(test_enemy.position_x).to eq(original_x)
            expect(test_enemy.position_y).to eq(original_y)
          end
        end
      end
    end

    context "プレイヤーが射程外にいるとき" do
      before do
        # Move players far away
        player1.update!(position_x: 1, position_y: 1)
        player2.update!(position_x: 13, position_y: 13)
        test_enemy.update!(position_x: 7, position_y: 7, previous_position_x: 7, previous_position_y: 7)
      end

      it "ランダムに移動すること" do
        original_x, original_y = test_enemy.position_x, test_enemy.position_y

        test_enemy.move(blank_game_map.map_data, [player1, player2], blank_game_round)

        # Should move to an adjacent cell
        new_x, new_y = test_enemy.position_x, test_enemy.position_y
        distance_moved = (new_x - original_x).abs + (new_y - original_y).abs
        expect(distance_moved).to eq(1)
      end
    end
  end

  describe "#find_player_in_range" do
    let(:player1) { Player.create!(game_round: blank_game_round, player_ai: player_ai_1, position_x: 5, position_y: 5, previous_position_x: 5, previous_position_y: 5, score: 0, character_level: 1, dynamite_left: 2, bomb_left: 2, walk_bonus_counter: 0, acquired_positive_items: [0, 0, 0, 0, 0, 0], status: :playing) }
    let(:player2) { Player.create!(game_round: blank_game_round, player_ai: player_ai_2, position_x: 13, position_y: 13, previous_position_x: 13, previous_position_y: 13, score: 0, character_level: 1, dynamite_left: 2, bomb_left: 2, walk_bonus_counter: 0, acquired_positive_items: [0, 0, 0, 0, 0, 0], status: :playing) }
    let(:test_enemy) { Enemy.create!(game_round: blank_game_round, position_x: 5, position_y: 5, previous_position_x: 5, previous_position_y: 5, state: :normal_state, enemy_kill: :no_kill) }

    it "P1が射程内、P2が射程外" do
      # Enemy at (5,5), P1 in range, P2 out of range
      result = test_enemy.send(:find_player_in_range, [player1, player2], blank_game_round)
      expect(result).to eq(player1)
    end

    it "P1が射程外、P2が射程内" do
      # Move P1 out of range, P2 into range
      player1.update!(position_x: 1, position_y: 1)
      player2.update!(position_x: 7, position_y: 7)

      result = test_enemy.send(:find_player_in_range, [player1, player2], blank_game_round)
      expect(result).to eq(player2)
    end

    it "P1, P2が射程内、P1の方が近いときはP1に向かうこと" do
      player1.update!(position_x: 6, position_y: 5)  # Distance 1
      player2.update!(position_x: 7, position_y: 5)  # Distance 2

      result = test_enemy.send(:find_player_in_range, [player1, player2], blank_game_round)
      expect(result).to eq(player1)
    end

    it "P1, P2が射程内、P2の方が近いときはP2に向かうこと" do
      player1.update!(position_x: 7, position_y: 5)  # Distance 2
      player2.update!(position_x: 6, position_y: 5)  # Distance 1

      result = test_enemy.send(:find_player_in_range, [player1, player2], blank_game_round)
      expect(result).to eq(player2)
    end

    it "P1, P2が等距離のとき" do
      # Equal distance, should select based on round number
      player1.update!(position_x: 6, position_y: 5)  # Distance 1
      player2.update!(position_x: 4, position_y: 5)  # Distance 1

      result = test_enemy.send(:find_player_in_range, [player1, player2], blank_game_round)
      # Round 1 (round_number - 1 = 0), should select first player
      expect(result).to eq(player1)
    end

    it "P1, P2が射程外のときはプレイヤーを見つけないこと" do
      player1.update!(position_x: 1, position_y: 1)
      player2.update!(position_x: 13, position_y: 13)

      result = test_enemy.send(:find_player_in_range, [player1, player2], blank_game_round)
      expect(result).to be_nil
    end
  end

  describe "Angry Mode" do
    let(:player1) { Player.create!(game_round: blank_game_round, player_ai: player_ai_1, position_x: 13, position_y: 1, previous_position_x: 13, previous_position_y: 1, score: 0, character_level: 1, dynamite_left: 2, bomb_left: 2, walk_bonus_counter: 0, acquired_positive_items: [0, 0, 0, 0, 0, 0], status: :playing) }
    let(:player2) { Player.create!(game_round: blank_game_round, player_ai: player_ai_2, position_x: 13, position_y: 13, previous_position_x: 13, previous_position_y: 13, score: 0, character_level: 1, dynamite_left: 2, bomb_left: 2, walk_bonus_counter: 0, acquired_positive_items: [0, 0, 0, 0, 0, 0], status: :playing) }
    let(:test_enemy) { Enemy.create!(game_round: blank_game_round, position_x: 1, position_y: 1, previous_position_x: 1, previous_position_y: 1, state: :normal_state, enemy_kill: :no_kill) }

    before do
      player1
      player2
      # Simulate turn 41+ for angry mode
      allow(test_enemy).to receive(:get_current_turn).and_return(Enemy::ANGRY_TURN)
    end

    it "ANGRY_TURNが41に設定されている" do
      expect(Enemy::ANGRY_TURN).to eq(41)
    end

    it "ターン41以降でangryステートに変更される" do
      test_enemy.send(:update_enemy_state, 41)
      expect(test_enemy.state).to eq("angry")
    end

    it "ターン40以下ではnormal_stateのまま" do
      test_enemy.send(:update_enemy_state, 40)
      expect(test_enemy.state).to eq("normal_state")
    end

    context "怒りモードでの移動" do
      before do
        test_enemy.update!(state: :angry)
      end

      it "プレイヤーが遠くにいても近づいていくこと" do
        _, _ = test_enemy.position_x, test_enemy.position_y

        test_enemy.move(blank_game_map.map_data, [player1, player2], blank_game_round)

        # Should move 1 step toward the closest player
        new_x, new_y = test_enemy.position_x, test_enemy.position_y
        expect([new_x, new_y]).to eq([2, 1])  # Moving toward player1
      end

      it "プレイヤーと同じマスにいるときは移動しない" do
        test_enemy.update!(position_x: 13, position_y: 1)  # Same as player1
        original_x, original_y = test_enemy.position_x, test_enemy.position_y

        test_enemy.move(blank_game_map.map_data, [player1, player2], blank_game_round)

        expect(test_enemy.position_x).to eq(original_x)
        expect(test_enemy.position_y).to eq(original_y)
      end

      it "プレイヤーの隣のマスにいるときは移動する（angry modeでは隣接していても攻撃的に移動）" do
        test_enemy.update!(position_x: 12, position_y: 1)  # Adjacent to player1

        test_enemy.move(blank_game_map.map_data, [player1, player2], blank_game_round)

        # Should move toward player1 (from 12,1 to 13,1)
        expect(test_enemy.position_x).to eq(13)
        expect(test_enemy.position_y).to eq(1)
      end

      it "歩数が少ないほうのプレイヤーに近づくこと" do
        # Player1 is closer (12 steps) than Player2 (24 steps)
        test_enemy.move(blank_game_map.map_data, [player1, player2], blank_game_round)

        # Should move toward player1 (right direction)
        expect(test_enemy.position_x).to eq(2)
        expect(test_enemy.position_y).to eq(1)
      end

      context "歩数が等しいとき" do
        it "1ラウンド目はP1に近づくこと" do
          player1.update!(position_x: 13, position_y: 1)
          player2.update!(position_x: 1, position_y: 13)

          test_enemy.move(blank_game_map.map_data, [player1, player2], blank_game_round)

          # Should move toward player1 (right)
          expect([test_enemy.position_x, test_enemy.position_y]).to eq([2, 1])
        end

        it "2ラウンド目はP2に近づくこと" do
          # Create round 2
          round2 = GameRound.create!(game: blank_game, round_number: 2, status: :in_progress, item_locations: {})
          test_enemy.update!(game_round: round2)
          player1.update!(game_round: round2, position_x: 13, position_y: 1)
          player2.update!(game_round: round2, position_x: 1, position_y: 13)

          test_enemy.move(blank_game_map.map_data, [player1, player2], round2)

          # Should move toward player2 (down)
          expect([test_enemy.position_x, test_enemy.position_y]).to eq([1, 2])
        end
      end

      it "盤面にいないプレイヤーは無視すること" do
        player2.update!(status: :completed)  # Player2 finished

        test_enemy.move(blank_game_map.map_data, [player1, player2], blank_game_round)

        # Should move toward only active player1
        expect([test_enemy.position_x, test_enemy.position_y]).to eq([2, 1])
      end
    end
  end

  describe "State transitions" do
    let(:test_enemy) { Enemy.create!(game_round: blank_game_round, position_x: 5, position_y: 5, previous_position_x: 5, previous_position_y: 5, state: :normal_state, enemy_kill: :no_kill) }

    it "ターン40では通常モードのまま" do
      test_enemy.send(:update_enemy_state, 40)
      expect(test_enemy).to be_normal
      expect(test_enemy).not_to be_angry
    end

    it "ターン41で怒りモードに変更" do
      test_enemy.send(:update_enemy_state, 41)
      expect(test_enemy).to be_angry
      expect(test_enemy).not_to be_normal
    end

    it "ターン50でも怒りモードを維持" do
      test_enemy.send(:update_enemy_state, 50)
      expect(test_enemy).to be_angry
    end
  end
end
