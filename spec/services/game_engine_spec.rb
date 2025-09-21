require "rails_helper"
require_relative "../../app/services/game_engine"
require_relative "../../app/services/ai_engine"
require_relative "../../app/services/turn_processor"

RSpec.describe GameEngine, type: :service do
  let!(:game_map) { create(:game_map) }
  let!(:first_player_ai) { create(:player_ai, :preset, code: "move_up") }
  let!(:second_player_ai) { create(:player_ai, :preset, code: "move_down") }
  let!(:game) do
    create(:game,
      game_map: game_map,
      first_player_ai: first_player_ai,
      second_player_ai: second_player_ai,
      status: :in_progress)
  end
  let(:game_engine) { described_class.new(game) }

  describe "#execute_battle" do
    context "正常なバトル実行の場合" do
      it "バトルを正常に実行する" do
        result = game_engine.execute_battle

        expect(result[:success]).to be true
        expect(result[:winner]).to be_in([:first, :second, nil])
        expect(result[:round_results]).to be_an(Array)
        expect(result[:round_results].size).to eq(GameConstants::N_ROUNDS)
      end

      it "ゲームラウンドが作成される" do
        expect {
          game_engine.execute_battle
        }.to change(GameRound, :count).by(GameConstants::N_ROUNDS)
      end

      it "プレイヤーが各ラウンドに作成される" do
        game_engine.execute_battle

        game.game_rounds.each do |round|
          expect(round.players.count).to eq(GameConstants::N_PLAYERS)
          expect(round.players.map(&:player_ai)).to contain_exactly(first_player_ai, second_player_ai)
        end
      end
    end

    context "AIエラーの場合" do
      before do
        first_player_ai.update!(code: "invalid_ruby_code")
      end

      it "エラーをハンドリングして続行する" do
        result = game_engine.execute_battle

        expect(result[:success]).to be true
        # プレイヤー1がタイムアウトしてもゲームは続行される
      end
    end
  end

  describe "#execute_round" do
    it "ラウンドを正常に実行する" do
      round_result = game_engine.send(:execute_round, 1)

      expect(round_result[:success]).to be true
      expect(round_result[:round_number]).to eq(1)
      expect(round_result[:winner]).to be_in([:player1, :player2, :draw])
      expect(round_result[:final_scores]).to be_an(Array)
    end

    it "ラウンドデータが正しく初期化される" do
      game_engine.send(:execute_round, 1)

      round = game.game_rounds.find_by(round_number: 1)
      expect(round).to be_present
      expect(round.status).to eq("finished")
      expect(round.players.count).to eq(2)
    end
  end

  describe "#initialize_players" do
    let(:round) { game.game_rounds.create!(round_number: 1, status: :preparing, item_locations: {}) }

    it "プレイヤーを正しく初期化する" do
      game_engine.send(:initialize_players, round)

      players = round.players.reload
      expect(players.count).to eq(2)

      players.each do |player|
        expect(player.score).to eq(0)
        expect(player.hp).to eq(100)
        expect(player.character_level).to eq(1)
        expect(player.dynamite_left).to eq(GameConstants::N_DYNAMITE)
        expect(player.bomb_left).to eq(GameConstants::N_BOMB)
        expect(player.status).to eq("playing")
      end
    end
  end

  describe "#check_win_conditions" do
    let(:round) { game.game_rounds.create!(round_number: 1, status: :in_progress, item_locations: {}) }
    let(:turn) { round.game_turns.create!(turn_number: 1, turn_finished: false) }
    let!(:player1) { round.players.create!(player_ai: first_player_ai, position_x: 1, position_y: 1, status: :playing, score: 0, hp: 100, character_level: 1, dynamite_left: 2, bomb_left: 2, walk_bonus_counter: 0, acquired_positive_items: [0, 0, 0, 0, 0, 0], previous_position_x: 1, previous_position_y: 1) }
    let!(:player2) { round.players.create!(player_ai: second_player_ai, position_x: 2, position_y: 2, status: :playing, score: 0, hp: 100, character_level: 1, dynamite_left: 2, bomb_left: 2, walk_bonus_counter: 0, acquired_positive_items: [0, 0, 0, 0, 0, 0], previous_position_x: 2, previous_position_y: 2) }

    before do
      game_engine.instance_variable_set(:@current_round, round)
      allow(game_engine).to receive(:reached_goal?).and_return(false)
    end

    context "プレイヤーがゴールに到達した場合" do
      it "ゴール勝利を返す" do
        allow(game_engine).to receive(:reached_goal?).with(player1).and_return(true)

        result = game_engine.send(:check_win_conditions, turn)

        expect(result[:type]).to eq(:goal_reached)
        expect(result[:players]).to include(player1)
      end
    end

    context "最大ターン数に達した場合" do
      let(:turn) { round.game_turns.create!(turn_number: GameConstants::MAX_TURN, turn_finished: false) }

      it "最大ターン終了を返す" do
        result = game_engine.send(:check_win_conditions, turn)

        expect(result[:type]).to eq(:max_turns)
      end
    end

    context "全プレイヤーが終了した場合" do
      before do
        player1.update!(status: :completed)
        player2.update!(status: :timeout)
      end

      it "全員終了を返す" do
        result = game_engine.send(:check_win_conditions, turn)

        expect(result[:type]).to eq(:all_finished)
      end
    end

    context "ゲーム続行の場合" do
      it "続行を返す" do
        result = game_engine.send(:check_win_conditions, turn)

        expect(result[:type]).to eq(:continue)
      end
    end
  end

  describe "#determine_overall_winner" do
    let(:round_results) do
      [
        {success: true, winner: :player1},
        {success: true, winner: :player2}
      ]
    end

    context "ラウンド勝利数が異なる場合" do
      let(:round_results) do
        [
          {success: true, winner: :player1},
          {success: true, winner: :player1}
        ]
      end

      it "勝利数の多いプレイヤーを返す" do
        result = game_engine.send(:determine_overall_winner, round_results)
        expect(result).to eq(:first)
      end
    end

    context "ラウンド勝利数が同じ場合" do
      it "総得点で判定する" do
        allow(game_engine).to receive(:determine_winner_by_total_score).and_return(:second)

        result = game_engine.send(:determine_overall_winner, round_results)
        expect(result).to eq(:second)
      end
    end
  end
end