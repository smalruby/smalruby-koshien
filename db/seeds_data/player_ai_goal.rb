require "smalruby3"

Stage.new(
  "Stage",
  costumes: [
    {
      asset_id: "cd21514d0531fdffb22204e0ec5ed84a",
      name: "背景1",
      bitmap_resolution: 1,
      data_format: "svg",
      rotation_center_x: 240,
      rotation_center_y: 180
    }
  ],
  lists: [
    {
      name: "最短経路"
    },
    {
      name: "通らない座標"
    }
  ]
) do
end

Sprite.new(
  "スプライト1",
  x: -140,
  y: 88,
  size: 50,
  costumes: [
    {
      asset_id: "7499cf6ec438d0c7af6f896bc6adc294",
      name: "コスチューム1",
      bitmap_resolution: 1,
      data_format: "svg",
      rotation_center_x: 87,
      rotation_center_y: 39
    }
  ]
) do
  def self.減点アイテムを避けながらゴールにむかって1マス進む
    koshien.locate_objects(result: list("$通らない座標"), cent: "7:7", sq_size: 15, objects: "ABCD")
    koshien.calc_route(result: list("$最短経路"), src: koshien.player, dst: koshien.goal, except_cells: list("$通らない座標"))
    if list("$最短経路").length == 1
      # 減点アイテムで囲まれてしまっている場合は減点アイテムを避けずにゴールに向かう
      koshien.calc_route(result: list("$最短経路"))
    end
    koshien.move_to(list("$最短経路")[2])
  end

  koshien.connect_game(name: "player1")
  koshien.get_map_area("2:2")
  koshien.get_map_area("7:2")
  koshien.turn_over
  koshien.get_map_area("12:2")
  koshien.get_map_area("2:7")
  koshien.turn_over
  koshien.get_map_area("7:7")
  koshien.get_map_area("12:7")
  koshien.turn_over
  koshien.get_map_area("2:12")
  koshien.get_map_area("7:12")
  koshien.turn_over
  koshien.get_map_area("12:12")

  減点アイテムを避けながらゴールにむかって1マス進む
  koshien.turn_over

  loop do
    koshien.get_map_area(koshien.player)
    減点アイテムを避けながらゴールにむかって1マス進む
    koshien.turn_over
  end
end
