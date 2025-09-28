require "rails_helper"

RSpec.describe BattleJob, type: :job do
  let(:valid_ai_code_1) do
    <<~RUBY
      require "smalruby3"

      Stage.new("Stage", lists: []) do
      end

      Sprite.new("Player1") do
        koshien.connect_game(name: "test_player_1")

        50.times do |turn|
          current_x = koshien.player_x
          if turn.even?
            # 偶数ターン: 右に移動
            koshien.move_to(koshien.position(current_x + 1, koshien.player_y))
          else
            # 奇数ターン: 左に移動
            koshien.move_to(koshien.position(current_x - 1, koshien.player_y))
          end
          koshien.turn_over
        end
      end
    RUBY
  end

  let(:valid_ai_code_2) do
    <<~RUBY
      require "smalruby3"

      Stage.new("Stage", lists: []) do
      end

      Sprite.new("Player2") do
        koshien.connect_game(name: "test_player_2")

        50.times do
          koshien.turn_over
        end
      end
    RUBY
  end

  let!(:game_map) { create(:game_map) }
  let!(:first_player_ai) { create(:player_ai, :preset, code: valid_ai_code_1) }
  let!(:second_player_ai) { create(:player_ai, :preset, code: valid_ai_code_2) }
  let!(:game) do
    create(:game,
      game_map: game_map,
      first_player_ai: first_player_ai,
      second_player_ai: second_player_ai,
      status: :in_progress)
  end

  describe "#perform" do
    context "正常なバトル実行の場合" do
      it "ゲームを正常に完了させ、必要なレコードを作成する" do
        expect {
          described_class.perform_now(game.id)
        }.to change { game.reload.status }.from("in_progress").to("completed")
          .and change(GameRound, :count).by(GameConstants::N_ROUNDS)
          .and change(GameTurn, :count).by_at_least(GameConstants::N_ROUNDS)
          .and change(Player, :count).by(GameConstants::N_ROUNDS * GameConstants::N_PLAYERS)
          .and change(GameEvent, :count).by_at_least(1)

        expect(game.completed_at).to be_present
        expect(game.winner).to be_in(["first", "second"])
      end
    end

    context "ゲームエンジンがエラーを返す場合" do
      before do
        allow_any_instance_of(GameEngine).to receive(:execute_battle).and_return({
          success: false,
          error: "Test error"
        })
      end

      it "ゲームをキャンセル状態にする" do
        expect {
          described_class.perform_now(game.id)
        }.to change { game.reload.status }.from("in_progress").to("cancelled")
      end
    end

    context "例外が発生した場合" do
      before do
        allow_any_instance_of(GameEngine).to receive(:execute_battle).and_raise(StandardError, "Unexpected error")
      end

      it "ゲームをキャンセル状態にして例外を再発生させる" do
        expect {
          described_class.perform_now(game.id)
        }.to raise_error(StandardError, "Unexpected error")
          .and change { game.reload.status }.from("in_progress").to("cancelled")
      end
    end

    context "存在しないゲームIDの場合" do
      it "ActiveRecord::RecordNotFoundを発生させる" do
        expect {
          described_class.perform_now(999999)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe "ジョブキュー設定" do
    it "デフォルトキューを使用する" do
      expect(described_class.queue_name).to eq("default")
    end
  end

  describe "非同期実行" do
    it "ジョブを非同期でエンキューできる" do
      expect {
        described_class.perform_later(game.id)
      }.to have_enqueued_job(described_class).with(game.id)
    end
  end
end
