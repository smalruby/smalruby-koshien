require "singleton"
require "json"
require "time"

# ダイクストラ法により最短経路を求める
module DijkstraSearch
  # 点
  # 各点は"m0_0"のような形式のID文字列をもつ
  class Node
    attr_accessor :id, :edges, :cost, :done, :from
    def initialize(id, edges = [], cost = nil, done = false)
      @id, @edges, @cost, @done = id, edges, cost, done
    end
  end

  # 辺
  # Note: Edgeのインスタンスは必ずNodeに紐付いているため、片方の点ID(nid)しか持っていない
  class Edge
    attr_reader :cost, :nid
    def initialize(cost, nid)
      @cost, @nid = cost, nid
    end
  end

  # グラフ
  class Graph
    # 新しいグラフをつくる
    # data : 点のIDから、辺の一覧へのハッシュ
    #   辺は[cost, nid]という形式
    def initialize(data)
      @nodes =
        data.map do |id, edges|
          edges.map! { |edge| Edge.new(*edge) }
          Node.new(id, edges)
        end
    end

    # 二点間の最短経路をNodeの一覧で返す(終点から始点へという順序なので注意)
    # sid : 始点のID(例："m0_0")
    # gid : 終点のID
    def route(sid, gid)
      dijkstra(sid)
      base = @nodes.find { |node| node.id == gid }

      # Check if destination is reachable (cost should not be nil)
      return [] if base.nil? || base.cost.nil?

      @res = [base]
      while base.from && (base = @nodes.find { |node| node.id == base.from })
        @res << base
      end
      @res
    end

    # 二点間の最短経路を座標の配列で返す
    # sid : 始点のID
    # gid : 終点のID
    def get_route(sid, gid)
      result = route(sid, gid)
      if result.empty?
        # When destination is unreachable, return only starting position
        sid =~ /\Am(\d+)_(\d+)\z/
        return [[$1.to_i, $2.to_i]]
      end

      result.reverse.map { |node|
        node.id =~ /\Am(\d+)_(\d+)\z/
        [$1.to_i, $2.to_i]
      }
    end

    # sidを始点としたときの、nidまでの最小コストを返す
    def cost(nid, sid)
      dijkstra(sid)
      @nodes.find { |node| node.id == nid }.cost
    end

    private

    # ある点からの最短経路を(破壊的に)設定する
    # Nodeのcost(最小コスト)とfrom(直前の点)が更新される
    # sid : 始点のID
    def dijkstra(sid)
      @nodes.each do |node|
        node.cost = (node.id == sid) ? 0 : nil
        node.done = false
        node.from = nil
      end
      loop do
        done_node = nil
        @nodes.each do |node|
          next if node.done || node.cost.nil?
          done_node = node if done_node.nil? || node.cost < done_node.cost
        end
        break unless done_node
        done_node.done = true
        done_node.edges.each do |edge|
          to = @nodes.find { |node| node.id == edge.nid }
          cost = done_node.cost + edge.cost
          from = done_node.id
          if to.cost.nil? || cost < to.cost
            to.cost = cost
            to.from = from
          end
        end
      end
    end
  end
end

module Smalruby3
  # スモウルビー甲子園のAIを作るためのクラス
  class Koshien
    include Singleton

    # Map chip constants for pathfinding
    BLANK_CHIP = {index: 0, weight: 1}
    WALL1_CHIP = {index: 1}
    WALL2_CHIP = {index: 2}
    WALL3_CHIP = {index: 5}
    WATER_CHIP = {index: 4, weight: 2}
    UNCLEARED_CHIP = {index: -1, weight: 4}
    ETC_CHIP = {weight: 3}

    def initialize
      # JSON mode state variables (from KoshienJsonAdapter)
      @actions = []
      @game_state = nil
      @player_name = nil
      @initialized = false
      @current_position = {x: 0, y: 0}  # Track position locally as fallback
      @current_turn_data = nil
      @current_turn = nil
      @rand_seed = nil
      @initialization_received = false
    end

    # --------------------------------------------------------------------------------
    # :section: 使用回数に制限がある命令
    # 1ターン内での使用回数に制限がある命令です。使用回数を超えた命令は無視されます。
    # --------------------------------------------------------------------------------

    # :call-seq:
    #   koshien.connect_game(name: "player1")
    #
    # プレイヤー名を (player1) にして、ゲームサーバーへ接続する
    #
    # #### 実行内容
    #
    # - ゲーム時に指定したプレイヤー名が表示されます。
    # - ゲームサーバーへ接続します。
    #
    # #### 引数
    #
    # - name: プレイヤー名を指定します。
    #
    # #### 解説
    #
    # - プレイヤーの名前は文字列14文字まで指定できます。
    #
    # #### 制限
    # - 1ゲームにつき1回しか実行できません。
    # - 2回目以降は無視されます。
    def connect_game(name:)
      if in_test_env?
        # Minimal stub for testing
        @player_name = name
        log("プレイヤー名を設定します: name=\"#{name}\"")
      elsif in_json_mode?
        # Store player name for JSON communication
        @player_name = name

        log("Connected to game as: #{name}")

        # Debug output
        warn "DEBUG connect_game: instance=#{object_id}, set @player_name=#{@player_name.inspect}"

        # If not yet initialized, initialize now
        if !@initialized
          warn "DEBUG connect_game: Not initialized yet, calling setup_json_communication"
          setup_json_communication
        end

        # Send ready message now that we have the player name
        if @initialization_received
          send_ready_message(name)
          warn "DEBUG connect_game: Sent ready message with player name: #{name}"
        else
          warn "DEBUG connect_game: Initialization not received yet, ready message will be sent later"
        end
      else
        # Original stub behavior
        log(%(プレイヤー名を設定します: name="#{name}"))
      end
    end

    # :call-seq:
    #   koshien.get_map_area("0:0")
    #
    # 座標が (0:0) 付近のマップ情報を取得する
    #
    # #### 実行内容
    #
    # - 指定した座標を中心とした5マス×5マスの範囲のマップ情報をゲームサーバーから取得します。
    #
    # #### 引数
    #
    # - マップ情報を取得したい範囲の中心の座標 `"x:y"` 形式を指定します。
    #
    # #### 解説
    #
    # - 取得できるマップ情報は、指定した範囲の以下の情報です。
    #     - マップ構成（空間・壁・水たまり・ゴール・壊せる壁）
    #     - 加点アイテム、減点アイテムがある場合は、その座標と種類解説
    #     - 対戦相手が指定範囲内にいる場合はその座標
    #     - 妨害キャラクタの現ターン開始時点の座標と前ターン開始時点の座標
    #     - （妨害キャラクタのみは指定範囲内にいなくても情報取得が可能）
    # - 取得したマップ情報は map 命令で参照します。
    #
    # #### 制限
    #
    # - move_to, get_map_area, set_dynamite, set_bomb の使用回数は1ターンにいずれか2回
    # - ただし、move_to 以外は同じ命令を2回使用することも可能です。
    #     - 使用回数を超えた命令は無視されます。
    def get_map_area(position)
      warn "DEBUG: get_map_area called with position: #{position.inspect}"
      if in_test_env?
        # Minimal stub for testing
        log("Get map area: #{position}")
        nil
      elsif in_json_mode?
        warn "DEBUG: in JSON mode, processing get_map_area"
        if position.is_a?(String) && position.include?(":")
          x, y = position.split(":").map(&:to_i)
          warn "DEBUG: parsed coordinates x=#{x}, y=#{y}"

          # Request map area data from game engine
          warn "DEBUG: requesting map area data from game engine"
          map_area_data = request_map_area(x, y)
          warn "DEBUG: received map area data: #{map_area_data.inspect}"

          # Add exploration action for event logging
          add_action({action_type: "explore", target_position: {x: x, y: y}, area_size: 5})
          warn "DEBUG: added exploration action to queue"

          # Return the map area data to the AI script
          warn "DEBUG: returning map area data to AI script"
          map_area_data
        else
          warn "DEBUG: invalid position format: #{position.inspect}"
          nil
        end
      else
        # Original stub behavior
        warn "DEBUG: not in JSON mode, using stub behavior"
        log("Get map area: #{position}")
        nil
      end
    end

    # :call-seq:
    #   koshien.move_to("0:0")
    #
    # 座標 (0:0) に移動する
    #
    # #### 実行内容
    #
    # - 指定した座標にプレイヤーが1マス移動します。
    # - 指定できるのは現在地から東西南北の1マスです。（斜めには移動できません）
    #
    # #### 引数
    #
    # - 移動先の座標 `"x:y"` 形式を指定します。
    #
    # #### 解説
    #
    # - 移動できるのは空間と水たまりだけで、壁には移動できません。
    # - 移動できない座標を指定した場合、使用回数はカウントされますが、実行は無視されます。
    # - 水たまりに移動した場合は、次回の移動命令が無視されます。（使用回数はカウントされます。）
    #
    # #### 制限
    #
    # - 1ターンに1回のみ
    # - move_to, get_map_area, set_dynamite, set_bomb の使用回数は1ターンにいずれか2回
    # - ただし、move_to 以外は同じ命令を2回使用することも可能です。
    #     - 使用回数を超えた命令は無視されます。
    def move_to(position)
      if in_test_env?
        # Minimal stub for testing
        log("Move to: #{position}")
      elsif in_json_mode?
        warn "🎯 move_to called with: #{position.inspect} (class: #{position.class})"
        if position.is_a?(String) && position.include?(":")
          x, y = position.split(":").map(&:to_i)
          warn "🎯 Parsed coordinates: (#{x}, #{y})"
          add_action({action_type: "move", target_x: x, target_y: y})
          # Track the intended movement for fallback position tracking
          track_movement_action(x, y)
        else
          warn "🎯 Invalid position format: #{position.inspect}"
        end
      else
        # Original stub behavior
        log("Move to: #{position}")
      end
    end

    # :call-seq:
    #   koshien.set_dynamite("0:0")
    #
    # [ダイナマイト] を座標 (0:0) に置く
    #
    # #### 実行内容
    #
    # - ダイナマイトを現在地又は隣接する東西南北のマスに設置します。
    #
    # #### 引数
    #
    # - ダイナマイトを設置したい座標 `"x:y"` 形式を指定します
    # - 引数を省略した場合は現在地にダイナマイトを設置します。
    #
    # #### 解説
    #
    # - ダイナマイトは、空間または水たまりの上に置くことができます。アイテムがあるマスには設置できません。
    # - ダイナマイトは１ラウンドに2回まで設置できます。
    # - 無効な座標を指定した場合、設置されませんが、ダイナマイトは1つ消費され、使用回数もカウントされます。
    # - 両プレイヤーが同じ座標に同時にダイナマイトを設置した場合、両プレイヤーとも設置は成功しますが、ダイナマイトは1つだけ設置されたことになります。
    # - ダイナマイトは設置したターンの終了時に爆発します。
    # - ダイナマイトが爆発すると、ダイナマイトのマスに隣接する「壊せる壁」は「空間」になり、次のターンから移動可能になります。
    # - ダイナマイトの爆発は「壊せる壁」以外の地形、プレイヤー、妨害キャラクタ、アイテムに影響を与えません。ダイナマイトが爆発したマスや隣接したマスにプレイヤーがいても減点されることはありません。
    #
    # #### 制限
    #
    # - move_to, get_map_area, set_dynamite, set_bomb の使用回数は1ターンにいずれか2回
    # - ただし、move_to 以外は同じ命令を2回使用することも可能です。
    #     - 使用回数を超えた命令は無視されます。
    def set_dynamite(position = nil)
      if in_test_env?
        # Minimal stub for testing
        log("Set dynamite at: #{position}")
      elsif in_json_mode?
        pos = position || player
        if pos.is_a?(String) && pos.include?(":")
          x, y = pos.split(":").map(&:to_i)
          add_action({action_type: "use_item", item: "dynamite", position: {x: x, y: y}})
        end
      else
        # Original stub behavior
        log("Set dynamite at: #{position}")
      end
    end

    # :call-seq:
    #   koshien.set_bomb("0:0")
    #
    # [爆弾] を座標 (0:0) に置く
    #
    # #### 実行内容
    #
    # - 爆弾を現在地又は隣接する東西南北のマスに設置します。
    #
    # #### 引数
    #
    # - 爆弾を設置したい座標 `"x:y"` 形式を指定します
    # - 引数を省略した場合は現在地に爆弾を設置します。
    #
    # #### 解説
    #
    # - 爆弾は、空間または水たまりの上に置くことができます。アイテムがあるマスには設置できません。
    # - 爆弾は１ラウンドに2回まで設置できます。
    # - 無効な座標を指定した場合、設置されませんが、爆弾は1つ消費され、使用回数もカウントされます。
    # - 両プレイヤーが同じ座標に同時に爆弾を設置した場合、両プレイヤーとも設置は成功しますが、爆弾は1つだけ設置されたことになります。
    #
    # #### 制限
    #
    # - move_to, get_map_area, set_dynamite, set_bomb の使用回数は1ターンにいずれか2回
    # - ただし、move_to 以外は同じ命令を2回使用することも可能です。
    #     - 使用回数を超えた命令は無視されます。
    def set_bomb(position = nil)
      if in_test_env?
        # Minimal stub for testing
        log("Set bomb at: #{position}")
      elsif in_json_mode?
        pos = position || player
        if pos.is_a?(String) && pos.include?(":")
          x, y = pos.split(":").map(&:to_i)
          add_action({action_type: "use_item", item: "bomb", position: {x: x, y: y}})
        end
      else
        # Original stub behavior
        log("Set bomb at: #{position}")
      end
    end

    # :call-seq:
    #   koshien.turn_over
    #
    # ターンを終了する
    #
    # #### 実行内容
    #
    # - 現在のターンを終了させ、次のターンを待ちます。
    #
    # #### 解説
    #
    # - 必ずターンの最後に1回実行する必要があります。
    # - **ターン終了を実行しないとタイムアウトでゲームが終了します。**
    #
    # #### 制限
    #
    # - (実行するとターンが終了するので) 1ターンに1回のみ
    def turn_over
      if in_test_env?
        log("Turn over")
      elsif in_json_mode?
        warn "🔄 turn_over: called, queue size=#{@message_queue.length}, actions=#{@actions.length}"

        send_turn_over
        # Clear actions AFTER sending them
        clear_actions
        warn "🔄 turn_over: calling wait_for_turn_completion"
        result = wait_for_turn_completion
        warn "🔄 turn_over: wait_for_turn_completion returned #{result}"

        # Wait for NEXT turn_start before returning
        # This ensures the loop only executes once per game turn
        # But stop if we get no messages (process being terminated)
        warn "🔄 turn_over: waiting for next turn_start"
        timeout_count = 0
        loop do
          msg = read_message
          warn "🔄 turn_over: received message type=#{msg&.dig("type")}"

          if msg && msg["type"] == "turn_start"
            update_turn_data(msg["data"])
            warn "🔄 turn_over: processed turn_start for turn #{msg.dig("data", "turn_number")}"
            break
          elsif msg.nil?
            timeout_count += 1
            warn "🔄 turn_over: no message received (#{timeout_count}/3)"
            if timeout_count >= 3
              warn "🔄 turn_over: no messages after 3 attempts, process likely terminated"
              break
            end
            sleep 0.1
          else
            warn "🔄 turn_over: ignoring message type=#{msg["type"]}"
          end
        end

        result
      else
        log("Turn over")
      end
    end

    # --------------------------------------------------------------------------------
    # :section: 使用回数の制限がない命令
    # 制限がなく、1ターン内で何度も使える命令です。
    # --------------------------------------------------------------------------------

    # :call-seq:
    #   koshien.position(0, 0) -> String
    #
    # 座標 (0) (0)
    #
    # #### 実行内容
    #
    # - x座標とy座標を `"x:y"` 形式の座標に変換します。
    #
    # #### 引数
    #
    # - x座標とy座標
    #
    # #### 解説
    #
    # - 各命令の引数に指定しやすいようにx座標とy座標の形式を変換できます。
    #
    #     ```ruby
    #     koshien.move_to(koshien.position(7, 7))
    #     ```
    def position(x, y)
      Position.new(x, y).to_s
    end

    # :call-seq:
    #   koshien.calc_route(result: list("$最短経路"), src: "0:0", dst: "0:0", except_cells: list("$通らない座標"))
    #
    # ２点間の最短経路 (始点 座標 (0:0) 、終点 座標 (0:0) 、通らない座標 リスト [通らない座標]) をリスト [最短経路] に保存する
    #
    # #### 実行内容
    #
    # - 指定した2点間の最短ルートを探します。
    # - 座標(`"x:y"`形式)のリストを通らない座標として指定すると、その座標を通らない経路を探します。
    # - 始点から終点までの座標(`"x:y"`形式)のリストを指定したリストに保存します。
    #
    # #### 引数
    #
    # - src: 始点の座標 `"x:y"` 形式を指定します。
    # - dst: 終点の座標 `"x:y"` 形式を指定します。
    # - except_cells: 経路を探すときに通ってほしくない座標(`"x:y"`形式)のリストを指定します。
    # - result: 探した最短経路の座標(`"x:y"`形式)のリストを保存するリストを指定します。
    #
    # #### 解説
    #
    # - 最短経路の座標のリストは「始点,次の移動先,･･･経路順の座標･･･,終点」の順番に並んでいます。
    # - 最短経路の各座標は並び順に0,1,2,3･･･の番号で指定できます。
    # - 指定した条件での経路がない場合は始点の座標が1つだけのリストが保存されます。
    # - get_map_area 命令でマップ情報を取得していない範囲のマス（未探索のマス）は全て移動可能とみなして経路探索するので注意が必要です。
    #   ただし、判明している空間マスがあれば、そちらを通る経路を優先します。
    # - 引数の指定例は次のとおりです。
    # - 例1: 始点、終点、通らない座標を指定して、ある座標(13, 9)からアイテムのある(7、7)への最短経路を探し、その経路で1マス移動する
    #
    #     ```ruby
    #     list("$通らない座標").clear
    #     list("$通らない座標").push("9:9")
    #     koshien.calc_route(result: list("$最短経路"), src: "13:9", dst: "7:7", except_cells: list("$通らない経路"))
    #     koshien.move_to(list("$最短経路")[1])
    #     ```
    #
    # - 例2: 通らない座標のみを指定して、ゴールまでの最短経路を探し、その経路で1マス移動する
    #
    #     ```ruby
    #     list("$通らない座標").clear
    #     list("$通らない座標").push("9:9")
    #     koshien.calc_route(result: list("$最短経路"), except_cells: list("$通らない経路"))
    #     koshien.move_to(list("$最短経路")[1])
    #     ```
    #
    # - 例3: ゴールまでの最短経路を探し、その経路で1マス移動する
    #
    #     ```ruby
    #     koshien.calc_route(result: list("$最短経路"))
    #     koshien.move_to(list("$最短経路")[1])
    #     ```
    def calc_route(result:, src: player, dst: goal, except_cells: nil)
      result ||= List.new

      # Parse src and dst coordinates
      src_coords = parse_position_string(src)
      dst_coords = parse_position_string(dst)

      warn "🗺️ calc_route: src=#{src_coords.inspect} dst=#{dst_coords.inspect}"

      if in_test_env?
        # Simple stub for testing - return direct path
        route = [[src_coords[0], src_coords[1]], [dst_coords[0], dst_coords[1]]]
      elsif in_json_mode?
        # Get current map data and calculate route using Dijkstra
        map_data = build_map_data_from_game_state
        except_cells_array = except_cells || []

        warn "🗺️ map_data size: #{map_data.size}x#{begin
          map_data.first&.size
        rescue
          "nil"
        end}"
        warn "🗺️ except_cells: #{except_cells_array.inspect}"

        # Build graph data for pathfinding
        graph_data = make_data(map_data, except_cells_array)
        graph = DijkstraSearch::Graph.new(graph_data)

        # Calculate route
        src_id = "m#{src_coords[0]}_#{src_coords[1]}"
        dst_id = "m#{dst_coords[0]}_#{dst_coords[1]}"
        warn "🗺️ Finding route from #{src_id} to #{dst_id}"
        route = graph.get_route(src_id, dst_id)
        warn "🗺️ Route found: #{route.inspect}"
      else
        # Fallback - simple direct path
        route = [[src_coords[0], src_coords[1]], [dst_coords[0], dst_coords[1]]]
      end

      # Convert route to position strings and update result list
      result.replace(route.map { |coords| "#{coords[0]}:#{coords[1]}" })
      warn "🗺️ Result list: #{result.inspect}"
      result
    end

    # :call-seq:
    #   koshien.map("0:0")
    #
    # 座標 (0:0) のマップ情報
    #
    # #### 実行内容
    #
    # - 指定した座標( `"x:y"` 形式)のマップ情報を参照します。
    #
    # #### 引数
    #
    # - 参照したい座標を `"x:y"` 形式で指定します。
    #
    # #### 解説
    #
    # - 参照するマップ情報は get_map_area 命令でゲームサーバーから取得した情報です。
    # - マップ情報を取得していない座標を指定した場合は、 `-1` が返されます。
    # - マップエリア外を指定した場合は、 `nil` が返されます。
    def map(position)
      if in_test_env?
        # Minimal stub for testing
        -1
      elsif in_json_mode?
        # Get map data from visible_map or return unknown
        coords = parse_position_string(position)
        x, y = coords

        # Check visible_map from current turn data
        if @current_turn_data && @current_turn_data["visible_map"]
          cell_key = "#{x}_#{y}"
          @current_turn_data["visible_map"][cell_key] || -1
        else
          -1 # Unknown/unexplored
        end
      else
        # Original stub behavior
        -1
      end
    end

    # :call-seq:
    #   koshien.map_all
    #
    # 全体のマップ情報
    #
    # #### 実行内容
    #
    # - マップ全体のマップ情報を文字列で取得します。
    #
    # #### 引数
    #
    # なし
    #
    # #### 解説
    #
    # - マップ情報は get_map_area 命令でゲームサーバーから取得した情報です。
    # - 横一列のマップ情報を示す15文字毎にカンマ区切りで、縦の15行分の文字列です (説明のためにカンマのあとに改行を入れていますが、実際には改行なしの長い文字列です)。
    #
    #     ```text
    #     000000000000000,
    #     000000000000000,
    #     000000000000000,
    #     000000000000000,
    #     000000000000000,
    #     000000000000000,
    #     000000000000000,
    #     000000000000000,
    #     000000000000000,
    #     000000000000000,
    #     000000000000000,
    #     000000000000000,
    #     000000000000000,
    #     000000000000000,
    #     000000000000000
    #     ```
    # - マップ情報を取得していない座標は `-` が返されます。マップ情報では `-1` で表現されますが、ここでは1文字で表現するために `-` としています。
    # - 取得したマップ情報は変数に代入することを想定しています。
    #
    #     ```ruby
    #     $すべてのマップ情報 = koshien.map_all
    #     ```
    # - さらに、そこからある座標のマップ情報を参照するには map_from メソッドを使います。
    def map_all
      if in_test_env?
        # Minimal stub for testing
        Map.new("").to_s
      elsif in_json_mode?
        # Build map string from visible_map data
        if @current_turn_data && @current_turn_data["visible_map"]
          build_map_string_from_visible_map
        else
          Map.new("").to_s
        end
      else
        # Original behavior
        Map.new("").to_s
      end
    end

    # :call-seq:
    #   koshien.map_from("0:0", $すべてのマップ情報)
    #
    # 座標 (0:0) のマップ情報を [すべてのマップ情報] から参照する
    #
    # #### 実行内容
    #
    # - map_all 命令で取得したマップから指定した座標( `"x:y"` 形式)のマップ情報を参照します。
    #
    # #### 引数
    #
    # - map_all 命令で取得したマップ、参照したい座標を `"x:y"` 形式で指定します。
    #
    # #### 解説
    #
    # - 参照するマップ情報は map_all 命令でゲームサーバーから取得した情報です。
    # - get_map_area 命令でマップ情報を取得していない座標を指定した場合は `-1` が返されます。
    # - マップエリア外の座標を指定した場合は `nil` が返されます。
    def map_from(position, from)
      map = Map.new(from)
      map.data(Position.new(position))
    end

    # :call-seq:
    #   koshien.locate_objects(result: list("$減点アイテム"), cent: "7:7", sq_size: 15, objects: "ABCD")
    #
    # 範囲内の地形・アイテム (中心 座標 (7:7) 、範囲 (15) 、地形・アイテム (ABCD))をリスト [減点アイテム] に保存する
    #
    # #### 実行内容
    #
    # - 指定した範囲に、指定した要素が存在するかどうかを確認します。
    # - 指定した要素がある座標を指定したリストに保存します。
    #
    # #### 引数
    #
    # - result: 結果を保存するリスト。あらかじめ作成しておく必要があります。
    # - cent: 指定する範囲の中心座標（省略時は現在地）
    # - sq_size: 指定する範囲の縦横のマスの長さ（省略時は5）
    # - objects: 確認したい要素の値。複数の場合は区切り文字なしで指定（省略時は減点アイテム全種類 `ABCD` ）
    #
    # #### 解説
    #
    # - 結果は指定したリストに保存します。
    # - リストの中の各座標はy座標が小さい順に並んでいます。（y座標が同じ場合は x座標の小さいほうが先になります。）
    # - マップ情報を取得していない座標の情報は確認できません。
    # - マップ全体を範囲指定したい場合は次のようになります。
    # - => 減点アイテム
    #     - 範囲内の地形・アイテム (中心 座標 (7:7) 、範囲 (15) 、地形・アイテム (ABCD))をリスト [減点アイテム] に保存する
    #     - `koshien.locate_objects(result: list("$減点アイテム"), cent: "7:7", sq_size: 15, objects: "ABCD")`
    # - => 加点アイテム
    #     - 範囲内の地形・アイテム (中心 座標 (7:7) 、範囲 (15) 、地形・アイテム (abcde))をリスト [加点アイテム] に保存する
    #     - `koshien.locate_objects(result: list("$加点アイテム"), cent: "7:7", sq_size: 15, objects: "abcde")`
    # - => 水たまり
    #     - 範囲内の地形・アイテム (中心 座標 (7:7) 、範囲 (15) 、地形・アイテム (4))をリスト [水たまり] に保存する
    #     - `koshien.locate_objects(result: list("$水たまり"), cent: "7:7", sq_size: 15, objects: "4")`
    def locate_objects(result:, sq_size: 5, cent: player, objects: "ABCD")
      result ||= List.new

      # Parse center position
      cent_coords = parse_position_string(cent)
      cent_x, cent_y = cent_coords

      # Calculate search area bounds
      half_size = sq_size / 2
      min_x = [0, cent_x - half_size].max
      max_x = [19, cent_x + half_size].min
      min_y = [0, cent_y - half_size].max
      max_y = [19, cent_y + half_size].min

      object_positions = []

      if in_json_mode?
        # Search through visible map for matching objects
        if @current_turn_data && @current_turn_data["visible_map"]
          visible_map = @current_turn_data["visible_map"]
          map_data = visible_map["map_data"]

          if map_data&.is_a?(Array)
            # Map data is a 2D array with string item marks
            # Positive items: "a"-"e"
            # Negative items: "A"-"D"
            (min_y..max_y).each do |y|
              next unless map_data[y]
              (min_x..max_x).each do |x|
                cell_value = map_data[y][x]
                next unless cell_value

                # Check if cell value is a string mark that matches requested objects
                if cell_value.is_a?(String) && objects.include?(cell_value)
                  object_positions << [x, y]
                end
              end
            end
          end
        end
      end

      # Convert to position strings and update result list
      # Sort by y coordinate first, then x coordinate (as per documentation)
      object_positions.sort_by! { |pos| [pos[1], pos[0]] }
      result.replace(object_positions.map { |coords| "#{coords[0]}:#{coords[1]}" })
      result
    end

    # :call-seq:
    #   koshien.position_of_x("0:0")
    #
    # (0:0) の [x座標]
    #
    # #### 実行内容
    #
    # - 座標 ( `"x:y"` 形式)からx座標を取得します
    #
    # #### 引数
    #
    # - 座標 ( `"x:y"` 形式)
    #
    # #### 解説
    #
    # - 最短経路命令や地形・アイテム命令で取得した座標 ( `"x:y"` 形式)からx座標を取得します
    def position_of_x(position)
      Position.new(position).x
    end

    # :call-seq:
    #   koshien.position_of_y("0:0")
    #
    # (0:0) の [y座標]
    #
    # #### 実行内容
    #
    # - 座標 ( `"x:y"` 形式)からy座標を取得します
    #
    # #### 引数
    #
    # - 座標 ( `"x:y"` 形式)
    #
    # #### 解説
    #
    # - 最短経路命令や地形・アイテム命令で取得した座標( `"x:y"` 形式)からy座標を取得します
    def position_of_y(position)
      Position.new(position).y
    end

    # :call-seq:
    #   koshien.other_player
    #
    # [対戦キャラクター] の [座標]
    #
    # #### 実行内容
    #
    # - 最後に get_map_area 命令で把握した対戦キャラクターの座標( `"x:y"` 形式)を返します。
    #
    # #### 解説
    #
    # - 得られる情報は、get_map_area 命令で把握した時点の情報です。
    # - 対戦キャラクターの座標は、get_map_area 命令の範囲に対戦キャラクターがいないと把握できません。
    # - 対戦キャラクターの座標を把握していない場合は `nil` が返されます。
    # - get_map_area 命令を繰り返し行っている場合、情報が上書きされていくため、一度把握した対戦キャラクターの座標を見失う場合があります。
    def other_player
      if in_test_env?
        # Minimal stub for testing
        nil
      else
        # JSON mode only - implementation will be added during integration
        raise "Traditional mode not supported. Use JSON mode only."
      end
    end

    # :call-seq:
    #   koshien.other_player_x
    #
    # [対戦キャラクター] の [x座標]
    #
    # #### 実行内容
    #
    # - 最後に get_map_area 命令で把握した対戦キャラクターのx座標を返します。
    #
    # #### 解説
    #
    # - 得られる情報は、get_map_area 命令で把握した時点の情報です。
    # - 対戦キャラクターの座標は、get_map_area 命令の範囲に対戦キャラクターがいないと把握できません。
    # - 対戦キャラクターの座標を把握していない場合は `nil` が返されます。
    # - get_map_area 命令を繰り返し行っている場合、情報が上書きされていくため、一度把握した対戦キャラクターの座標を見失う場合があります。
    def other_player_x
      if in_test_env?
        # Minimal stub for testing
        nil
      else
        # JSON mode only - implementation will be added during integration
        raise "Traditional mode not supported. Use JSON mode only."
      end
    end

    # :call-seq:
    #   koshien.other_player_y
    #
    # [対戦キャラクター] の [y座標]
    #
    # #### 実行内容
    #
    # - 最後に get_map_area 命令で把握した対戦キャラクターのy座標を返します。
    #
    # #### 解説
    #
    # - 得られる情報は、get_map_area 命令で把握した時点の情報です。
    # - 対戦キャラクターの座標は、get_map_area 命令の範囲に対戦キャラクターがいないと把握できません。
    # - 対戦キャラクターの座標を把握していない場合は `nil` が返されます。
    # - get_map_area 命令を繰り返し行っている場合、情報が上書きされていくため、一度把握した対戦キャラクターの座標を見失う場合があります。
    def other_player_y
      if in_test_env?
        # Minimal stub for testing
        nil
      else
        # JSON mode only - implementation will be added during integration
        raise "Traditional mode not supported. Use JSON mode only."
      end
    end

    # :call-seq:
    #   koshien.enemy
    #
    # [妨害キャラクター] の [座標]
    #
    # #### 実行内容
    #
    # - 最後に get_map_area 命令を実行した時点の妨害キャラクターの座標( `"x:y"` 形式)を返します。
    #
    # #### 解説
    #
    # - 得られる情報は、最後に get_map_area 命令を実行した時点の情報です。
    # - 妨害キャラクターの座標は、 get_map_area 命令の範囲に妨害キャラクターがいなくても把握できます。
    def enemy
      if in_test_env?
        # Minimal stub for testing
        nil
      else
        # JSON mode only - implementation will be added during integration
        raise "Traditional mode not supported. Use JSON mode only."
      end
    end

    # :call-seq:
    #   koshien.enemy_x
    #
    # [妨害キャラクター] の [x座標]
    #
    # #### 実行内容
    #
    # - 最後に get_map_area 命令を実行した時点の妨害キャラクターのx座標を返します。
    #
    # #### 解説
    #
    # - 得られる情報は、最後に get_map_area 命令を実行した時点の情報です。
    # - 妨害キャラクターの座標は、 get_map_area 命令の範囲に妨害キャラクターがいなくても把握できます。
    def enemy_x
      if in_test_env?
        # Minimal stub for testing
        nil
      else
        # JSON mode only - implementation will be added during integration
        raise "Traditional mode not supported. Use JSON mode only."
      end
    end

    # :call-seq:
    #   koshien.enemy_y
    #
    # [妨害キャラクター] の [y座標]
    #
    # #### 実行内容
    #
    # - 最後に get_map_area 命令を実行した時点の妨害キャラクターのy座標を返します。
    #
    # #### 解説
    #
    # - 得られる情報は、最後に get_map_area 命令を実行した時点の情報です。
    # - 妨害キャラクターの座標は、 get_map_area 命令の範囲に妨害キャラクターがいなくても把握できます。
    def enemy_y
      if in_test_env?
        # Minimal stub for testing
        nil
      else
        # JSON mode only - implementation will be added during integration
        raise "Traditional mode not supported. Use JSON mode only."
      end
    end

    # :call-seq:
    #   koshien.goal
    #
    # [ゴール] の [座標]
    #
    # #### 実行内容
    #
    # - ゴールの座標( `"x:y"` 形式)を返します。
    #
    # #### 解説
    #
    # - ゴールの座標は、マップ情報を取得していなくても参照できます。
    def goal
      if in_test_env?
        # Minimal stub for testing
        "14:14"
      elsif in_json_mode?
        pos = goal_position
        # Handle both string and symbol keys
        x = pos["x"] || pos[:x]
        y = pos["y"] || pos[:y]
        result = "#{x}:#{y}"
        warn "🎯 koshien.goal called: pos=#{pos.inspect}, result=#{result.inspect}"
        result
      else
        "14:14"
      end
    end

    # :call-seq:
    #   koshien.goal_x
    #
    # [ゴール] の [x座標]
    #
    # #### 実行内容
    #
    # - ゴールのx座標を返します。
    #
    # #### 解説
    #
    # - ゴールの座標は、マップ情報を取得していなくても参照できます。
    def goal_x
      if in_test_env?
        # Minimal stub for testing
        14
      elsif in_json_mode?
        pos = goal_position
        pos["x"] || pos[:x]
      else
        14
      end
    end

    # :call-seq:
    #   koshien.goal_y
    #
    # [ゴール] の [y座標]
    #
    # #### 実行内容
    #
    # - ゴールのy座標を返します。
    #
    # #### 解説
    #
    # - ゴールの座標は、マップ情報を取得していなくても参照できます。
    def goal_y
      if in_test_env?
        # Minimal stub for testing
        14
      elsif in_json_mode?
        pos = goal_position
        pos["y"] || pos[:y]
      else
        14
      end
    end

    # :call-seq:
    #   koshien.player
    #
    # [プレイヤー] の [座標]
    #
    # #### 実行内容
    #
    # - プレイヤーの座標( `"x:y"` 形式)を返します。
    #
    # #### 解説
    #
    # - プレイヤーの座標は、マップ情報を取得していなくても参照できます。
    def player
      if in_test_env?
        # Minimal stub for testing
        position(0, 0)
      elsif in_json_mode?
        pos = current_player_position
        result = "#{pos[:x]}:#{pos[:y]}"
        warn "🎯 koshien.player called: pos=#{pos.inspect}, result=#{result.inspect}"
        result
      else
        position(0, 0)
      end
    end

    # :call-seq:
    #   koshien.player_x
    #
    # [プレイヤー] の [x座標]
    #
    # #### 実行内容
    #
    # - プレイヤーのx座標を返します。
    #
    # #### 解説
    #
    # - プレイヤーの座標は、マップ情報を取得していなくても参照できます。
    def player_x
      if in_test_env?
        # Minimal stub for testing
        0
      elsif in_json_mode?
        current_player_position[:x]
      else
        0
      end
    end

    # :call-seq:
    #   koshien.player_y
    #
    # [プレイヤー] の [y座標]
    #
    # #### 実行内容
    #
    # - プレイヤーのy座標を返します。
    #
    # #### 解説
    #
    # - プレイヤーの座標は、マップ情報を取得していなくても参照できます。
    def player_y
      if in_test_env?
        # Minimal stub for testing
        0
      elsif in_json_mode?
        current_player_position[:y]
      else
        0
      end
    end

    # :call-seq:
    #   koshien.object("water")
    #   koshien.object("水たまり")
    #
    # [水たまり]
    #
    # #### 実行内容
    #
    # - 「水たまり」「草薙剣」などの指定したマップ情報の種類に対応したマップ情報(水たまりは `4` 、草薙剣は `"e"` など)を取得します
    #
    # #### 引数
    #
    # - マップ情報の種類
    #
    # #### 解説
    #
    # - マップ情報の種類に対応したマップ情報を使って、例えば map 命令で取得したマップ情報を比較することができます。
    # - 例: 座標 7:7 が水たまりならば xxx を行う (xxx は任意の命令を示しています)
    #
    #     ```ruby
    #     if koshien.map("7:7") == koshien.object("water")
    #       xxx
    #     end
    #     ```
    def object(name)
      case name
      when "unknown", "未探索のマス", "みたんさくのマス"
        -1
      when "space", "空間", "くうかん"
        0
      when "wall", "壁", "かべ"
        1
      when "storehouse", "蔵", "くら"
        2
      when "goal", "ゴール"
        3
      when "water", "水たまり", "みずたまり"
        4
      when "breakable wall", "壊せる壁", "こわせるかべ"
        5
      when "tea", "お茶", "おちゃ"
        "a"
      when "sweets", "和菓子", "わがし"
        "b"
      when "COIN", "丁銀", "ちょうぎん"
        "c"
      when "dolphin", "シロイルカ"
        "d"
      when "sword", "草薙剣", "くさなぎのつるぎ"
        "e"
      when "poison", "毒キノコ", "どくキノコ"
        "A"
      when "snake", "蛇", "へび"
        "B"
      when "trap", "トラバサミ"
        "C"
      when "bomb", "爆弾", "ばくだん"
        "D"
      else
        -1
      end
    end

    # :call-seq:
    #   koshien.set_message("こんにちは")
    #
    # メッセージ[こんにちは]
    #
    # #### 実行内容
    #
    # - メッセージを表示します。
    #
    # #### 引数
    #
    # - メッセージ。最大100文字。
    #
    # #### 解説
    #
    # - AI開発時の動作確認に使うことを想定しています。
    def set_message(message)
      if in_test_env?
        # Minimal stub for testing
        log("Message: #{message}")
      elsif in_json_mode?
        send_debug_message(message.to_s)
      else
        # Original stub behavior
        log("Message: #{message}")
      end
    end

    private

    # JSON communication methods (migrated from KoshienJsonAdapter)

    def setup_json_communication
      @initialized = true
      @message_queue = []  # Queue for storing unexpected messages

      # Debug output
      warn "DEBUG setup_json_communication: instance=#{object_id}, @player_name=#{@player_name.inspect}"

      # Wait for initialization message from AiProcessManager first
      warn "DEBUG: Waiting for initialize message from AiProcessManager..."
      message = read_message
      warn "DEBUG: Received message: #{message.inspect}"

      if message && message["type"] == "initialize"
        @game_state = message["data"]
        @rand_seed = @game_state["rand_seed"]
        srand(@rand_seed) if @rand_seed

        # Initialize position from initial_position if available
        if @game_state["initial_position"]
          @current_position = {
            x: @game_state["initial_position"]["x"],
            y: @game_state["initial_position"]["y"]
          }
          warn "DEBUG: Initialized @current_position from game state: #{@current_position.inspect}"
        end

        # Store initialization success but don't send ready message yet
        # Ready message will be sent when connect_game is called
        @initialization_received = true
        warn "DEBUG: Initialization received, waiting for connect_game"
        true
      else
        warn "DEBUG: setup_json_communication failed - unexpected message type or nil"
        false
      end
    end

    def run_game_loop
      loop do
        message = read_message
        break unless message

        case message["type"]
        when "turn_start"
          handle_turn_start(message["data"])
        when "turn_end_confirm"
          handle_turn_end_confirm(message["data"])
        when "game_end"
          handle_game_end(message["data"])
          break
        else
          send_error_message("Unknown message type: #{message["type"]}")
        end
      end
    end

    def add_action(action)
      @actions << action
      warn "➕ Action added: #{action.inspect}, total actions: #{@actions.length}"
    end

    def clear_actions
      @actions.clear
    end

    def get_actions
      @actions.dup
    end

    def request_map_area(x, y)
      warn "DEBUG: request_map_area starting for x=#{x}, y=#{y}"

      # Check if there's a queued map_area_response first
      warn "DEBUG: checking message queue (size=#{@message_queue.length})"
      queued_response = @message_queue.find { |msg| msg["type"] == "map_area_response" }
      if queued_response
        warn "DEBUG: found queued map_area_response, removing from queue"
        @message_queue.delete(queued_response)
        warn "DEBUG: returning queued response data"
        return queued_response["data"]
      end

      # Send map area request message
      request_message = {
        type: "map_area_request",
        timestamp: Time.now.utc.iso8601,
        data: {
          x: x,
          y: y,
          area_size: 5
        }
      }
      warn "DEBUG: sending map area request: #{request_message.inspect}"
      send_message(request_message)

      # Wait for response, queuing any turn_start messages that arrive
      warn "DEBUG: waiting for map area response..."
      loop do
        response = read_message
        warn "DEBUG: received response: #{response.inspect}"

        case response&.dig("type")
        when "map_area_response"
          warn "DEBUG: got valid map_area_response"
          return response["data"]
        when "turn_start"
          # Only keep the latest turn_start - discard any old ones
          warn "DEBUG: received turn_start while waiting for map area"
          @message_queue.reject! { |msg| msg["type"] == "turn_start" }
          @message_queue << response
          warn "DEBUG: replaced any old turn_start in queue (queue size now: #{@message_queue.length})"
          # Continue waiting for map_area_response
        when nil
          warn "ERROR: No response received for map area request"
          return nil
        else
          warn "ERROR: Unexpected message type while waiting for map area: #{response["type"]}"
          # Queue other messages and continue waiting
          @message_queue << response if response
        end
      end
    end

    def current_player_position
      # Prioritize locally tracked position (reflects moves made during turn)
      # over turn_start data (position at start of turn)
      if @current_position
        warn "DEBUG current_player_position: using @current_position=#{@current_position.inspect}"
        return @current_position
      end

      # Fallback to turn data if local position not available
      if @current_turn_data && @current_turn_data["current_player"]
        current_player = @current_turn_data["current_player"]
        warn "DEBUG current_player_position: using turn data current_player=#{current_player.inspect}"

        # Handle both possible data structures
        if current_player["position"]
          result = current_player["position"]
          warn "DEBUG current_player_position: using position=#{result.inspect}"
          return result
        elsif current_player["x"] && current_player["y"]
          result = {x: current_player["x"], y: current_player["y"]}
          warn "DEBUG current_player_position: using x/y=#{result.inspect}"
          return result
        end
      end

      # Final fallback to default position
      warn "DEBUG current_player_position: no position available, returning nil"
      nil
    end

    def other_players
      @current_turn_data&.dig("other_players") || []
    end

    def enemies
      @current_turn_data&.dig("enemies") || []
    end

    def visible_map
      @current_turn_data&.dig("visible_map") || {}
    end

    def goal_position
      @game_state&.dig("game_map", "goal_position") || {x: 14, y: 14}
    end

    def extract_player_name_from_script
      # Use stored player name if available, otherwise extract from script filename
      @player_name || (
        if $0 && File.basename($0).match?(/stage_\d+_(.+)\.rb/)
          File.basename($0, ".rb").gsub(/^stage_\d+_/, "")
        else
          "json_ai_player"
        end
      )
    end

    def send_ready_message(player_name)
      # Use the stored player name from connect_game if available
      final_player_name = @player_name || player_name
      @player_name = final_player_name

      # Debug output
      warn "DEBUG: @player_name=#{@player_name.inspect}, player_name=#{player_name.inspect}, final=#{final_player_name.inspect}"

      send_message({
        type: "ready",
        timestamp: Time.now.utc.iso8601,
        data: {
          player_name: final_player_name,
          ai_version: "1.0.0",
          status: "initialized"
        }
      })
    end

    def update_turn_data(data)
      @current_turn_data = data
      @current_turn = data["turn_number"]

      # Update local position tracking when we receive turn data
      if data["current_player"]
        current_player = data["current_player"]
        if current_player && current_player["x"] && current_player["y"]
          @current_position = {x: current_player["x"], y: current_player["y"]}
        end
      end
    end

    def handle_turn_start(data)
      update_turn_data(data)
      # Clear previous actions when starting a new turn
      clear_actions
    end

    def handle_turn_end_confirm(data)
      send_debug_message("Turn #{data["turn_number"]} confirmed, #{data["actions_processed"]} actions processed")
    end

    def handle_game_end(data)
      send_debug_message("Game ended: #{data["reason"]}, final score: #{data.fetch("final_score", 0)}")
    end

    def send_message(message)
      $stdout.puts(message.to_json)
      $stdout.flush
    end

    def send_debug_message(message)
      send_message({
        type: "debug",
        timestamp: Time.now.utc.iso8601,
        data: {
          level: "info",
          message: message,
          context: {
            current_action: "debug",
            turn_number: @current_turn
          }
        }
      })
    end

    def send_error_message(error_message)
      send_message({
        type: "error",
        timestamp: Time.now.utc.iso8601,
        data: {
          error_type: "runtime_error",
          message: error_message,
          details: {}
        }
      })
    end

    def send_turn_over
      actions = get_actions
      warn "📤 Sending turn_over with #{actions.length} actions: #{actions.inspect}"
      send_message({
        type: "turn_over",
        timestamp: Time.now.utc.iso8601,
        data: {
          actions: actions
        }
      })
    end

    def wait_for_turn_completion
      warn "🔄 wait_for_turn_completion: starting, queue size=#{@message_queue.length}"
      loop do
        message = read_message
        warn "🔄 wait_for_turn_completion: received message type=#{message&.dig("type")}"
        return false unless message

        case message["type"]
        when "turn_end_confirm"
          warn "🔄 wait_for_turn_completion: received turn_end_confirm, returning true"
          handle_turn_end_confirm(message["data"])
          return true
        when "game_end"
          warn "🔄 wait_for_turn_completion: received game_end, exiting"
          handle_game_end(message["data"])
          exit(0)
        when "turn_start"
          # Only keep the latest turn_start - discard any old ones
          # This prevents accumulating stale turn_start messages
          warn "🔄 wait_for_turn_completion: received turn_start"
          @message_queue.reject! { |msg| msg["type"] == "turn_start" }
          @message_queue << message
          warn "🔄 wait_for_turn_completion: replaced any old turn_start in queue (queue size now: #{@message_queue.length})"
          # Continue waiting for turn_end_confirm
        else
          warn "🔄 wait_for_turn_completion: unexpected message type #{message["type"]}, returning false"
          send_error_message("Unexpected message type during turn completion: #{message["type"]}")
          return false
        end
      end
    end

    def track_movement_action(target_x, target_y)
      # Update the fallback position to track intended movements
      # This helps when turn data doesn't arrive properly
      @current_position = {x: target_x, y: target_y}
      warn "DEBUG track_movement_action: updated @current_position to #{@current_position.inspect}"
    end

    def read_message
      line = $stdin.gets
      return nil unless line

      JSON.parse(line.chomp)
    rescue JSON::ParserError => e
      send_error_message("Invalid JSON: #{e.message}")
      nil
    end

    def in_json_mode?
      # JSON mode is now the default behavior
      # Only disable if explicitly set to false
      ENV["KOSHIEN_JSON_MODE"] != "false"
    end

    # Helper methods for calc_route

    def parse_position_string(pos_str)
      if pos_str.is_a?(String) && pos_str.include?(":")
        pos_str.split(":").map(&:to_i)
      else
        [0, 0] # default fallback
      end
    end

    def build_map_data_from_game_state
      # Extract real map data from visible_map if available
      if @current_turn_data && @current_turn_data["visible_map"] && @current_turn_data["visible_map"]["map_data"]
        # Use the actual map data from the game
        @current_turn_data["visible_map"]["map_data"]
      elsif @game_state && @game_state["game_map"] && @game_state["game_map"]["map_data"]
        # Fallback to initial game map data
        @game_state["game_map"]["map_data"]
      else
        # Last resort: create a basic 20x20 map with open spaces
        Array.new(20) { Array.new(20, BLANK_CHIP[:index]) }
      end
    end

    def build_map_string_from_visible_map
      # Build a 15x15 map string from visible_map data
      rows = []
      (0...15).each do |y|
        row = ""
        (0...15).each do |x|
          cell_key = "#{x}_#{y}"
          if @current_turn_data["visible_map"][cell_key]
            # Use actual map data if available
            cell_value = @current_turn_data["visible_map"][cell_key]
            row += cell_value.to_s
          else
            # Use '-' for unexplored areas
            row += "-"
          end
        end
        rows << row
      end
      rows.join(",")
    end

    def make_data(map, except_cells)
      except_cells.each do |cell|
        # Handle both string format "x:y" and array format [x, y]
        if cell.is_a?(String)
          ex, ey = parse_position_string(cell)
        else
          ex, ey = cell
        end
        map[ey][ex] = WALL1_CHIP[:index] if map[ey] && map[ey][ex]
      end

      data = {}
      map.size.times do |y|
        map.first.size.times do |x|
          res = []
          [[x, y - 1], [x, y + 1], [x - 1, y], [x + 1, y]].each do |dx, dy|
            next if dx < 0 || dy < 0
            if map[dy] && map[dy][dx]
              case map[dy][dx]
              # 加点アイテムの扱い（通路）
              when "a".."e"
                res << [BLANK_CHIP[:weight], "m#{dx}_#{dy}"]
              # 減点アイテムの扱い（通路）
              when "A".."D"
                res << [BLANK_CHIP[:weight], "m#{dx}_#{dy}"]
              # 通路
              when BLANK_CHIP[:index]
                res << [BLANK_CHIP[:weight], "m#{dx}_#{dy}"]
              # 水たまり
              when WATER_CHIP[:index]
                res << [WATER_CHIP[:weight], "m#{dx}_#{dy}"]
              # 未探査セル（通路扱い）
              when UNCLEARED_CHIP[:index]
                res << [UNCLEARED_CHIP[:weight], "m#{dx}_#{dy}"]
              # 壁
              when WALL1_CHIP[:index], WALL2_CHIP[:index], WALL3_CHIP[:index]
                # 通れないので辺として追加しない
              else
                res << [ETC_CHIP[:weight], "m#{dx}_#{dy}"]
              end
            end
          end
          data["m#{x}_#{y}"] = res
        end
      end
      data
    end

    def in_test_env?
      defined?(Rails) && Rails.env.test?
    end

    def log(message)
      if in_test_env?
        # Simple logging for testing
        puts message
      end
    end
  end
end

require_relative "koshien/position"
require_relative "koshien/map"
