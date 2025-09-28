require "smalruby3"

# 段階(1): 何もせずにタイムアウトする
#
# 成功条件:
# - 1ターンで終了していること
# - 得点が0のままであること

Stage.new(
  "Stage",
  lists: []
) do
end

Sprite.new(
  "スプライト1"
) do
  koshien.connect_game(name: "timeout")

  # 何もしない（ターンを終了しない）
  # タイムアウトまで待機
  loop do
  end
end
