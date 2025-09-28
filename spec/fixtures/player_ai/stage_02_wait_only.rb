require "smalruby3"

# 段階(2): 最後までターンを進めるだけで終わる
#
# 成功条件:
# - 50ターンまでターンが進むこと
# - 最初から最後までPlayerの位置が変わらないこと
# - 得点が0のままであること

Stage.new(
  "Stage",
  lists: []
) do
end

Sprite.new(
  "スプライト1"
) do
  koshien.connect_game(name: "wait_only")

  # 50ターンまで何もせずにターンを終了するだけ
  50.times do
    koshien.turn_over
  end
end
