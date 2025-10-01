require "smalruby3"

# 段階(5): 最後まで同じ場所を探索するだけ
#
# 成功条件:
# - 50ターンまでターンが進むこと
# - 最初から最後までPlayerの位置が変わらないこと
# - 各ターンで、マップ情報の探索結果を踏まえた情報を、AiProcessManagerからAiプロセスの標準入力にわたすこと
# - 移動した分の得点が加算されないこと
# - enemyと接触した回数だけ減点されること (1回接触するごとに-10点)

Stage.new(
  "Stage",
  lists: []
) do
end

Sprite.new(
  "スプライト1"
) do
  koshien.connect_game(name: "local_explore")

  # 50ターンまで同じ場所を探索するだけ
  50.times do
    # 現在位置周辺を探索
    current_position = koshien.player
    koshien.get_map_area(current_position)

    # デバッグ用メッセージ
    koshien.set_message("同じ場所を探索中: #{current_position}")

    koshien.turn_over
  end
end
