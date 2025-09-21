require "rails_helper"

RSpec.describe BattleJob, type: :job do
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

  describe "#perform" do
    context "正常なバトル実行の場合" do
      it "ゲームを正常に完了させる" do
        expect {
          described_class.perform_now(game.id)
        }.to change { game.reload.status }.from("in_progress").to("completed")

        expect(game.completed_at).to be_present
        expect(game.winner).to be_in(["first", "second"])
      end

      it "ゲームラウンドとターンが作成される" do
        expect {
          described_class.perform_now(game.id)
        }.to change(GameRound, :count).by(GameConstants::N_ROUNDS)
          .and change(GameTurn, :count).by_at_least(GameConstants::N_ROUNDS)
      end

      it "プレイヤーが作成される" do
        expect {
          described_class.perform_now(game.id)
        }.to change(Player, :count).by(GameConstants::N_ROUNDS * GameConstants::N_PLAYERS)
      end

      it "ゲームイベントが作成される" do
        expect {
          described_class.perform_now(game.id)
        }.to change(GameEvent, :count).by_at_least(1)
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
