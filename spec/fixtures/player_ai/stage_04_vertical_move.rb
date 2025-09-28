require "smalruby3"

# 段階(4): 最後まで上下に往復するだけ
#
# 成功条件:
# - 50ターンまでターンが進むこと
# - 命令に従って各ターンでPlayerのy座標が+1, -1, +1, -1と変化すること
# - 移動した分の得点が加算されること

Stage.new(
  "Stage",
  lists: []
) do
end

Sprite.new(
  "スプライト1"
) do
  koshien.connect_game(name: "v_move")

  # 50ターンまで上下に往復移動
  50.times do |turn|
    current_y = koshien.player_y
    if turn.even?
      # 偶数ターン: 下に移動
      koshien.move_to(koshien.position(koshien.player_x, current_y + 1))
    else
      # 奇数ターン: 上に移動
      koshien.move_to(koshien.position(koshien.player_x, current_y - 1))
    end
    koshien.turn_over
  end
end
