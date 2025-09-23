# 段階(2): 最後までターンを進めるだけで終わる
#
# 成功条件:
# - 50ターンまでターンが進むこと
# - 最初から最後までPlayerの位置が変わらないこと
# - 得点が0のままであること

require "smalruby3"

# JSON mode での通信開始
if ENV["KOSHIEN_JSON_MODE"] == "true"
  adapter = Smalruby3::KoshienJsonAdapter.instance
  if adapter.setup_json_communication
    adapter.run_game_loop
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
  koshien.connect_game(name: "wait_only_player")

  # 50ターンまで何もせずにターンを終了するだけ
  50.times do
    koshien.turn_over
  end
end
