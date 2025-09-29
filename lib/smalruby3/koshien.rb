require "singleton"
require "json"
require "timeout"
require "time"

module Smalruby3
  # スモウルビー甲子園のAIを作るためのクラス
  class Koshien
    include Singleton

    # JSON communication attributes
    attr_accessor :io_input, :io_output, :game_state, :turn_number, :round_number
    attr_accessor :player_position, :other_player_position, :enemy_position
    attr_accessor :my_map, :item_locations, :dynamite_count, :bomb_count
    attr_accessor :current_message, :action_count, :last_map_area_info
    attr_accessor :actions, :initialized, :initialization_received, :current_turn_data, :current_turn

    def initialize
      @io_input = $stdin
      @io_output = $stdout
      @game_state = {}
      @turn_number = 0
      @round_number = 0
      @player_position = [0, 0]
      @current_position = {x: 0, y: 0}  # Track position locally as fallback
      @goal_position = [0, 0]
      @other_player_position = nil
      @enemy_position = nil
      @my_map = Array.new(15) { Array.new(15, -1) }
      @item_locations = {}
      @dynamite_count = 2
      @bomb_count = 2
      @current_message = ""
      @action_count = 0
      @last_map_area_info = {}
      @actions = []
      @initialized = false
      @initialization_received = false
      @current_turn_data = nil
      @current_turn = 0
    end

    # Setup JSON communication with AI process
    def setup_json_communication
      @initialized = true
      @actions = []
      @initialization_received = false

      # Wait for initialization message from AiProcessManager first
      message = receive_json_message

      if message && message["type"] == "initialize"
        @game_state = message["data"] || {}
        @rand_seed = @game_state["rand_seed"]
        srand(@rand_seed) if @rand_seed

        # Initialize position from initial_position if available
        if @game_state["initial_position"]
          @player_position = [
            @game_state["initial_position"]["x"] || 0,
            @game_state["initial_position"]["y"] || 0
          ]
          @current_position = {
            x: @game_state["initial_position"]["x"] || 0,
            y: @game_state["initial_position"]["y"] || 0
          }
        end

        @initialization_received = true
        true
      else
        false
      end
    end

    # Main game loop - wait for turns and execute
    def run_game_loop
      loop do
        message = receive_json_message
        break unless message

        case message["type"]
        when "turn_start"
          handle_turn_start_message(message["data"])
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

    # Game state accessors
    def current_player_position
      # First try to get position from current turn data
      if @current_turn_data && @current_turn_data["current_player"]
        current_player = @current_turn_data["current_player"]

        # Handle both possible data structures
        if current_player["position"]
          result = current_player["position"]
          return result
        elsif current_player["x"] && current_player["y"]
          result = {x: current_player["x"], y: current_player["y"]}
          return result
        end
      end

      # Fallback to locally tracked position
      @current_position
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
      # Return instance variable if set (for tests), otherwise get from game state
      @goal_position || @game_state&.dig("game_map", "goal_position") || {x: 14, y: 14}
    end

    def goal_position=(position)
      @goal_position = position
    end

    # Update position when movements are planned (fallback position tracking)
    def track_movement_action(target_x, target_y)
      # Update the fallback position to track intended movements
      # This helps when turn data doesn't arrive properly
      @current_position = {x: target_x, y: target_y}
    end

    # Request map area data from game engine (synchronous call)
    def request_map_area(x, y)
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
      send_json_message(request_message)

      # Wait for response
      response = receive_json_message

      if response && response["type"] == "map_area_response"
        response["data"]
      end
    end

    # Action collection methods
    def add_action(action)
      @actions ||= []
      @actions << action
    end

    def clear_actions
      @actions = []
    end

    def get_actions
      (@actions || []).dup
    end

    # Handle turn start from AI process manager
    def handle_turn_start(turn_data)
      @turn_number = turn_data["turn"] || @turn_number
      @round_number = turn_data["round"] || @round_number

      if turn_data["game_state"]
        @game_state = turn_data["game_state"]
        update_game_state_from_json(@game_state)
      end

      @action_count = 0

      # Notify AI that turn is ready
      send_json_message({
        type: "turn_ready",
        turn: @turn_number,
        round: @round_number,
        player_position: @player_position,
        goal_position: @goal_position
      })
    end

    # Send turn over signal to AI process
    def send_turn_over
      actions = get_actions
      send_json_message({
        type: "turn_over",
        timestamp: Time.now.utc.iso8601,
        data: {
          actions: actions
        }
      })
      clear_actions
    end

    # Wait for turn processing to complete
    def wait_for_turn_completion
      loop do
        message = receive_json_message
        return false unless message

        case message["type"]
        when "turn_end_confirm"
          handle_turn_end_confirm(message["data"])
          return true # Turn completed, continue to next turn
        when "game_end"
          handle_game_end(message["data"])
          exit(0) # Game finished, exit script
        when "turn_start"
          # New turn started, update state and return
          handle_turn_start_message(message["data"])
          return true
        else
          send_error_message("Unexpected message type during turn completion: #{message["type"]}")
          return false
        end
      end
    end

    # Turn start message handler (different from handle_turn_start)
    def handle_turn_start_message(data)
      @current_turn_data = data
      @current_turn = data["turn_number"]

      # Update local position tracking when we receive turn data
      if data["current_player"]
        current_player = data["current_player"]
        if current_player["x"] && current_player["y"]
          @player_position = [current_player["x"], current_player["y"]]
          # Also update current_position for compatibility
          @current_position = {x: current_player["x"], y: current_player["y"]}
        end
      end

      # Clear previous actions
      clear_actions
    end

    def handle_turn_end_confirm(data)
      send_debug_message("Turn #{data["turn_number"]} confirmed, #{data["actions_processed"]} actions processed")
    end

    def handle_game_end(data)
      send_debug_message("Game ended: #{data["reason"]}, final score: #{data.fetch("final_score", 0)}")
    end

    def send_debug_message(message)
      send_json_message({
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
      send_json_message({
        type: "error",
        timestamp: Time.now.utc.iso8601,
        data: {
          error_type: "runtime_error",
          message: error_message,
          details: {}
        }
      })
    end

    private

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

      send_json_message({
        type: "ready",
        timestamp: Time.now.utc.iso8601,
        data: {
          player_name: final_player_name,
          ai_version: "1.0.0",
          status: "initialized"
        }
      })
    end

    def send_json_message(message)
      json_str = JSON.generate(message)
      @io_output.puts(json_str)
      @io_output.flush
    end

    def receive_json_message(timeout_seconds = 30)
      Timeout.timeout(timeout_seconds) do
        line = @io_input.gets
        return nil unless line
        JSON.parse(line.strip)
      end
    rescue Timeout::Error, JSON::ParserError => e
      log("JSON communication error: #{e.message}")
      nil
    end

    def update_game_state_from_json(state)
      if state["player"]
        @player_position = [state["player"]["x"] || 0, state["player"]["y"] || 0]
        @dynamite_count = state["player"]["dynamite_left"] || 2
        @bomb_count = state["player"]["bomb_left"] || 2
      end

      if state["goal"]
        @goal_position = [state["goal"]["x"] || 0, state["goal"]["y"] || 0]
      end

      @other_player_position = if state["other_player"]
        [state["other_player"]["x"], state["other_player"]["y"]]
      end

      @enemy_position = if state["enemies"]&.any?
        enemy = state["enemies"].first
        [enemy["x"], enemy["y"]]
      end

      if state["map"]
        @my_map = state["map"]
      end

      if state["items"]
        @item_locations = state["items"]
      end
    end

    public

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
      # Store the player name for later use in ready response
      @player_name = name

      # Send ready message now that we have the player name
      if @initialization_received
        send_ready_message(@player_name)
        return true
      end

      # For regular JSON mode (not AiProcessManager), send connect_game message
      send_json_message({
        type: "connect_game",
        player_name: name
      })

      response = receive_json_message
      if response && response["type"] == "connection_established"
        log(%(プレイヤー名を設定します: name="#{name}"))
        true
      else
        log("Failed to connect to game")
        false
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
      return nil if @action_count >= 2

      if position.is_a?(String) && position.include?(":")
        x, y = position.split(":").map(&:to_i)

        if @initialization_received
          # AI ProcessManager mode - use async communication
          map_area_data = request_map_area(x, y)
          add_action({action_type: "explore", target_position: {x: x, y: y}, area_size: 5})
          @action_count += 1
          map_area_data
        else
          # Traditional JSON mode - send get_map_area message and wait for response
          send_json_message({
            type: "get_map_area",
            position: position,
            x: x,
            y: y
          })

          response = receive_json_message
          if response && response["type"] == "map_area_data"
            @action_count += 1
            response["data"]
          else
            nil
          end
        end
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
      if position.is_a?(String) && position.include?(":")
        x, y = position.split(":").map(&:to_i)

        # For AI ProcessManager mode, use action-based approach
        if @initialization_received
          add_action({action_type: "move", target_x: x, target_y: y})
          # Track the intended movement for fallback position tracking
          track_movement_action(x, y)
          return
        end

        # For traditional JSON mode, use synchronous approach
        return nil if @action_count >= 2

        send_json_message({
          type: "move_to",
          position: {x: x, y: y},
          turn: @turn_number
        })

        response = receive_json_message
        if response && response["type"] == "move_result"
          if response["success"]
            @player_position = [x, y]
          end
          @action_count += 1
          return response["success"]
        end

        false
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
      return nil if @action_count >= 2
      return nil if @dynamite_count <= 0

      if position.nil?
        target_x, target_y = @player_position
      else
        pos = Position.new(position)
        target_x, target_y = pos.x, pos.y
      end

      send_json_message({
        type: "set_dynamite",
        position: {x: target_x, y: target_y},
        turn: @turn_number
      })

      response = receive_json_message
      if response && response["type"] == "dynamite_result"
        if response["success"]
          @dynamite_count -= 1
        end
        @action_count += 1
        return response["success"]
      end

      false
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
      return nil if @action_count >= 2
      return nil if @bomb_count <= 0

      if position.nil?
        target_x, target_y = @player_position
      else
        pos = Position.new(position)
        target_x, target_y = pos.x, pos.y
      end

      send_json_message({
        type: "set_bomb",
        position: {x: target_x, y: target_y},
        turn: @turn_number
      })

      response = receive_json_message
      if response && response["type"] == "bomb_result"
        if response["success"]
          @bomb_count -= 1
        end
        @action_count += 1
        return response["success"]
      end

      false
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
      send_turn_over
      # Wait for turn processing to complete before returning control to script
      wait_for_turn_completion
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
    def calc_route(result:, src: nil, dst: nil, except_cells: nil)
      result ||= List.new

      # Parse source and destination positions
      src_pos = src ? Position.new(src) : Position.new(@player_position[0], @player_position[1])
      dst_pos = dst ? Position.new(dst) : Position.new(@goal_position[0], @goal_position[1])

      # Parse except_cells if provided
      except_positions = []
      if except_cells&.respond_to?(:length)
        # Handle Smalruby3::List (1-based indexing)
        (1..except_cells.length).each do |i|
          cell = except_cells[i]
          pos = Position.new(cell)
          except_positions << [pos.x, pos.y]
        end
      elsif except_cells.respond_to?(:each)
        # Handle regular Array
        except_cells.each do |cell|
          pos = Position.new(cell)
          except_positions << [pos.x, pos.y]
        end
      end

      # Use Dijkstra's algorithm to find shortest path
      route = dijkstra_pathfind(src_pos.x, src_pos.y, dst_pos.x, dst_pos.y, except_positions)

      # Convert route to position strings
      route_strings = route.map { |coords| Position.new(coords[0], coords[1]).to_s }
      result.replace(route_strings)
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
      pos = Position.new(position)
      x, y = pos.x, pos.y

      # Check bounds
      return nil if x < 0 || x >= 15 || y < 0 || y >= 15

      # Return map data or -1 for unknown
      @my_map[y][x] || -1
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
      # Convert 2D array to comma-separated string format
      rows = @my_map.map do |row|
        row.map { |cell| (cell == -1) ? "-" : cell.to_s }.join
      end
      rows.join(",")
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
    def locate_objects(result:, sq_size: 5, cent: nil, objects: "ABCD")
      result ||= List.new

      # Parse center position
      if cent.nil?
        center_x, center_y = @player_position
      else
        pos = Position.new(cent)
        center_x, center_y = pos.x, pos.y
      end

      # Calculate search area bounds
      half_size = sq_size / 2
      min_x = [center_x - half_size, 0].max
      max_x = [center_x + half_size, 14].min
      min_y = [center_y - half_size, 0].max
      max_y = [center_y + half_size, 14].min

      object_positions = []

      # Search for objects in the specified area
      (min_y..max_y).each do |y|
        (min_x..max_x).each do |x|
          cell_value = @my_map[y][x]

          # Skip unknown cells
          next if cell_value == -1

          # Check if cell contains any of the target objects
          cell_str = cell_value.to_s
          if objects.include?(cell_str)
            object_positions << [x, y]
          end
        end
      end

      # Sort by y coordinate first, then x coordinate
      object_positions.sort! { |a, b| (a[1] != b[1]) ? (a[1] <=> b[1]) : (a[0] <=> b[0]) }

      # Convert to position strings
      result.replace(object_positions.map { |coords| Position.new(coords[0], coords[1]).to_s })
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
      return nil unless @other_player_position
      Position.new(@other_player_position[0], @other_player_position[1]).to_s
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
      @other_player_position ? @other_player_position[0] : nil
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
      @other_player_position ? @other_player_position[1] : nil
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
      return nil unless @enemy_position
      Position.new(@enemy_position[0], @enemy_position[1]).to_s
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
      @enemy_position ? @enemy_position[0] : nil
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
      @enemy_position ? @enemy_position[1] : nil
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
      Position.new(@goal_position[0], @goal_position[1]).to_s
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
      @goal_position[0]
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
      @goal_position[1]
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
      Position.new(@player_position[0], @player_position[1]).to_s
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
      @player_position[0]
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
      @player_position[1]
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
      @current_message = message.to_s[0, 100] # Limit to 100 characters

      send_json_message({
        type: "set_message",
        message: @current_message,
        turn: @turn_number
      })
    end

    private

    def update_map_from_area_data(area_data, center_x, center_y)
      return unless area_data["map"]

      # Update 5x5 area around center point
      area_map = area_data["map"]
      (-2..2).each do |dy|
        (-2..2).each do |dx|
          map_x = center_x + dx
          map_y = center_y + dy
          area_idx_x = dx + 2
          area_idx_y = dy + 2

          if map_x >= 0 && map_x < 15 && map_y >= 0 && map_y < 15 &&
              area_idx_x >= 0 && area_idx_x < 5 && area_idx_y >= 0 && area_idx_y < 5
            @my_map[map_y][map_x] = area_map[area_idx_y][area_idx_x]
          end
        end
      end

      # Update other player position from area data
      if area_data["other_player"]
        @other_player_position = [area_data["other_player"]["x"], area_data["other_player"]["y"]]
      end

      # Update enemy position from area data
      if area_data["enemies"] && !area_data["enemies"].empty?
        enemy = area_data["enemies"].first
        @enemy_position = [enemy["x"], enemy["y"]]
      end
    end

    # Dijkstra pathfinding implementation
    def dijkstra_pathfind(start_x, start_y, goal_x, goal_y, except_cells = [])
      # Convert except_cells to set for faster lookup
      except_set = Set.new(except_cells)

      # Priority queue: [distance, x, y, path]
      queue = [[0, start_x, start_y, [[start_x, start_y]]]]
      visited = Set.new

      until queue.empty?
        distance, x, y, path = queue.shift

        # Skip if already visited
        next if visited.include?([x, y])
        visited.add([x, y])

        # Check if we reached the goal
        if x == goal_x && y == goal_y
          return path
        end

        # Explore neighbors (up, down, left, right)
        [[0, -1], [0, 1], [-1, 0], [1, 0]].each do |dx, dy|
          next_x = x + dx
          next_y = y + dy

          # Check bounds
          next if next_x < 0 || next_x >= 15 || next_y < 0 || next_y >= 15

          # Skip if in except_cells
          next if except_set.include?([next_x, next_y])

          # Skip if already visited
          next if visited.include?([next_x, next_y])

          # Check if cell is passable
          cell_value = @my_map[next_y][next_x]
          # Passable: 0 (space), 3 (goal), 4 (water), -1 (unknown - assume passable)
          next unless [0, 3, 4, -1].include?(cell_value)

          # Add to queue with updated path
          new_path = path + [[next_x, next_y]]
          queue << [distance + 1, next_x, next_y, new_path]
        end

        # Sort queue by distance (simple priority queue)
        queue.sort_by! { |item| item[0] }
      end

      # No path found, return just the starting position
      [[start_x, start_y]]
    end

    def log(message)
      # Simple logging - could be expanded if needed
      warn message if ENV["KOSHIEN_DEBUG"]
    end
  end
end

require_relative "koshien/position"
require_relative "koshien/map"
