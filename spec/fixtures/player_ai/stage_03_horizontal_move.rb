require "smalruby3"

# 段階(3): 最後まで左右に往復するだけ
#
# 成功条件:
# - 50ターンまでターンが進むこと
# - 命令に従って各ターンでPlayerのx座標が+1, -1, +1, -1と変化すること
# - 移動した分の得点が加算されること (5回移動するごとに3点)
# - enemyと接触した回数だけ減点されること (1回接触するごとに-10点)

Stage.new(
  "Stage",
  lists: []
) do
end

Sprite.new(
  "スプライト1"
) do
  koshien.connect_game(name: "h_move")

  # 50ターンまで左右に往復移動
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
