# 段階(1): 何もせずにタイムアウトする
#
# 成功条件:
# - 1ターンで終了していること
# - 得点が0のままであること

require "smalruby3"

# JSON mode での通信開始
if ENV["KOSHIEN_JSON_MODE"] == "true"
  # First, create koshien instance and connect to game
  Stage.new("Stage", lists: []) do
  end

  Sprite.new("スプライト1") do
    koshien.connect_game(name: "timeout_player")
  end

  # Then setup JSON communication but don't run game loop to cause timeout
  adapter = Smalruby3::KoshienJsonAdapter.instance
  if adapter.setup_json_communication
    # タイムアウト用のスタブ実装 - ゲームループを開始せずに待機
    sleep(10) # 意図的にタイムアウトを発生させる
  end
  exit(0)
end

Stage.new(
  "Stage",
  lists: []
) do
end

Sprite.new(
  "スプライト1"
) do
  koshien.connect_game(name: "timeout_player")

  # 何もしない（ターンを終了しない）
  # タイムアウトまで待機
end
