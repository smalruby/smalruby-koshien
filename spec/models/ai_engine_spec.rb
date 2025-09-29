require "rails_helper"

RSpec.describe AiEngine, type: :model do
  let(:ai_engine) { described_class.new }
  let!(:game_map) { create(:game_map) }

  describe "#execute_ai" do
    let!(:player_ai) { create(:player_ai, code: ai_code) }
    let!(:game) { create(:game, game_map: game_map, first_player_ai: player_ai, second_player_ai: player_ai) }
    let!(:round) { game.game_rounds.create!(round_number: 1, status: :in_progress, item_locations: {}) }
    let!(:turn) { round.game_turns.create!(turn_number: 1, turn_finished: false) }
    let!(:player) do
      round.players.create!(
        player_ai: player_ai,
        position_x: 1,
        position_y: 1,
        previous_position_x: 1,
        previous_position_y: 1,
        score: 0,
        character_level: 1,
        dynamite_left: 2,
        bomb_left: 2,
        walk_bonus_counter: 0,
        acquired_positive_items: [0, 0, 0, 0, 0, 0],
        status: :playing
      )
    end
    let(:game_state) do
      {
        player: player.api_info,
        enemies: [],
        map: game_map.map_data,
        items: {},
        turn: 1,
        round: 1
      }
    end
    context "正常なAIコードの場合" do
      let(:ai_code) { "move_up" }

      it "AIを正常に実行する" do
        result = ai_engine.execute_ai(player: player, game_state: game_state, turn: turn)

        expect(result).to be_a(Hash)
        expect(result[:actions]).to be_present
        expect(result[:actions].first[:type]).to eq("move")
        expect(result[:actions].first[:direction]).to eq("up")
      end
    end

    context "複数のアクションを返すAIコードの場合" do
      let(:ai_code) do
        <<~RUBY
          move_up
          use_dynamite
        RUBY
      end

      it "複数のアクションを実行する" do
        result = ai_engine.execute_ai(player: player, game_state: game_state, turn: turn)

        expect(result[:actions]).to be_an(Array)
        expect(result[:actions].size).to eq(2)
        expect(result[:actions][0][:type]).to eq("move")
        expect(result[:actions][1][:type]).to eq("use_item")
      end
    end

    context "情報取得APIを使用するAIコードの場合" do
      let(:ai_code) do
        <<~RUBY
          player_info = get_player_info
          enemy_info = get_enemy_info
          map_info = get_map_info
          item_info = get_item_info
          turn_info = get_turn_info

          if player_info[:x] > 0
            move_left
          else
            move_right
          end
        RUBY
      end

      it "ゲーム情報を取得して適切に動作する" do
        result = ai_engine.execute_ai(player: player, game_state: game_state, turn: turn)

        expect(result[:actions]).to be_present
        expect(result[:actions].first[:type]).to eq("move")
        expect(result[:actions].first[:direction]).to be_in(["left", "right"])
      end
    end

    context "waitアクションのAIコードの場合" do
      let(:ai_code) { "wait" }

      it "waitアクションを実行する" do
        result = ai_engine.execute_ai(player: player, game_state: game_state, turn: turn)

        expect(result[:actions]).to be_present
        expect(result[:actions].first[:type]).to eq("wait")
      end
    end

    context "無効なRubyコードの場合" do
      let(:ai_code) { "invalid_ruby_syntax {" }

      it "AIExecutionErrorを発生させる" do
        expect {
          ai_engine.execute_ai(player: player, game_state: game_state, turn: turn)
        }.to raise_error(AiEngine::AiExecutionError)
      end
    end

    context "危険なコードの場合" do
      let(:ai_code) { "system('rm -rf /')" }

      it "SecurityErrorまたはNoMethodErrorを発生させる" do
        expect {
          ai_engine.execute_ai(player: player, game_state: game_state, turn: turn)
        }.to raise_error(AiEngine::AiExecutionError)
      end
    end

    context "実行時間が長すぎる場合" do
      let(:ai_code) { "sleep(2)" }
      # Use optimized AI engine with 1 second timeout for faster testing
      let(:ai_engine) { AiEngine.new(timeout_duration: 1) }

      it "AITimeoutErrorを発生させる" do
        expect {
          ai_engine.execute_ai(player: player, game_state: game_state, turn: turn)
        }.to raise_error(AiEngine::AiTimeoutError)
      end
    end
  end

  describe "#valid_action?" do
    let(:test_ai_engine) { described_class.new }

    it "有効な移動アクションを認識する" do
      action = {type: "move", direction: "up"}
      expect(test_ai_engine.send(:valid_action?, action)).to be true
    end

    it "有効なアイテム使用アクションを認識する" do
      action = {type: "use_item", item: "dynamite"}
      expect(test_ai_engine.send(:valid_action?, action)).to be true
    end

    it "有効なwaitアクションを認識する" do
      action = {type: "wait"}
      expect(test_ai_engine.send(:valid_action?, action)).to be true
    end

    it "無効なアクションを拒否する" do
      action = {type: "invalid_action"}
      expect(test_ai_engine.send(:valid_action?, action)).to be false
    end

    it "不正な形式のアクションを拒否する" do
      expect(test_ai_engine.send(:valid_action?, "invalid")).to be false
      expect(test_ai_engine.send(:valid_action?, {direction: "up"})).to be false
    end
  end

  describe "AiExecutionContext" do
    let!(:test_player_ai) { create(:player_ai, code: "test") }
    let!(:test_game) { create(:game, game_map: game_map, first_player_ai: test_player_ai, second_player_ai: test_player_ai) }
    let!(:test_round) { test_game.game_rounds.create!(round_number: 1, status: :in_progress, item_locations: {}) }
    let!(:test_turn) { test_round.game_turns.create!(turn_number: 1, turn_finished: false) }
    let!(:test_player) do
      test_round.players.create!(
        player_ai: test_player_ai,
        position_x: 1,
        position_y: 1,
        previous_position_x: 1,
        previous_position_y: 1,
        score: 0,
        character_level: 1,
        dynamite_left: 2,
        bomb_left: 2,
        walk_bonus_counter: 0,
        acquired_positive_items: [0, 0, 0, 0, 0, 0],
        status: :playing
      )
    end
    let(:test_game_state) do
      {
        player: test_player.api_info,
        enemies: [],
        map: game_map.map_data,
        items: {},
        turn: 1,
        round: 1
      }
    end
    let(:context) { AiEngine::AiExecutionContext.new(test_player, test_game_state, test_turn) }

    describe "安全なAPIメソッド" do
      it "プレイヤー情報を取得できる" do
        player_info = context.get_player_info
        expect(player_info[:id]).to eq(test_player.id)
        expect(player_info[:x]).to eq(test_player.position_x)
        expect(player_info[:y]).to eq(test_player.position_y)
      end

      it "敵情報を取得できる" do
        enemy_info = context.get_enemy_info
        expect(enemy_info).to be_an(Array)
      end

      it "マップ情報を取得できる" do
        map_info = context.get_map_info
        expect(map_info).to eq(game_map.map_data)
      end

      it "アイテム情報を取得できる" do
        item_info = context.get_item_info
        expect(item_info).to be_a(Hash)
      end

      it "ターン情報を取得できる" do
        turn_info = context.get_turn_info
        expect(turn_info[:turn]).to eq(1)
        expect(turn_info[:round]).to eq(1)
      end
    end

    describe "移動メソッド" do
      it "上移動アクションを追加する" do
        result = context.move_up
        expect(result[:type]).to eq("move")
        expect(result[:direction]).to eq("up")
      end

      it "下移動アクションを追加する" do
        result = context.move_down
        expect(result[:type]).to eq("move")
        expect(result[:direction]).to eq("down")
      end

      it "左移動アクションを追加する" do
        result = context.move_left
        expect(result[:type]).to eq("move")
        expect(result[:direction]).to eq("left")
      end

      it "右移動アクションを追加する" do
        result = context.move_right
        expect(result[:type]).to eq("move")
        expect(result[:direction]).to eq("right")
      end
    end

    describe "アイテム使用メソッド" do
      it "ダイナマイト使用アクションを追加する" do
        result = context.use_dynamite
        expect(result[:type]).to eq("use_item")
        expect(result[:item]).to eq("dynamite")
      end

      it "爆弾使用アクションを追加する" do
        result = context.use_bomb
        expect(result[:type]).to eq("use_item")
        expect(result[:item]).to eq("bomb")
      end

      it "待機アクションを追加する" do
        result = context.wait
        expect(result[:type]).to eq("wait")
      end
    end
  end
end
