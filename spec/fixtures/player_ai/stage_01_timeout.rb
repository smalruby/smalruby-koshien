# 段階(1): 何もせずにタイムアウトする
#
# 成功条件:
# - 1ターンで終了していること
# - 得点が0のままであること

require "smalruby3"

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
  loop do
  end
end
