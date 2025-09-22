# ビューア経由で起動された場合は、出力をファイルにリダイレクトする
if ENV["SK_LOG_PATH"]
  $stdout.reopen(ENV["SK_LOG_PATH"], "a")
  $stdout.sync = true
  $stderr.reopen(ENV["SK_LOG_PATH"], "a")
  $stderr.sync = true
end

if (seed_str = ENV["SK_RANDOM_SEED"])
  seed = seed_str.to_i
  srand(seed)
end

require "net/http"
require "uri"
require "json"
require "securerandom"
require "singleton"
require "logger"

require_relative "smalruby_patch"
require_relative "../../shared/dijkstra_search"

module AI
  def set_name(name)
    AILib.instance.logger.info(%(プレイヤー名を設定します: name="#{name}"))
    AILib.instance.player_name = name
    nil
  end

  def connect_game
    AILib.instance.connectGame
    nil
  end

  def move_to(pos)
    AILib.instance.move_to(*pos)
    nil
  end

  def calc_route(args = {})
    AILib.instance.calc_route(args)
  end

  def get_map_area(x, y)
    AILib.instance.get_map_area(x, y)
  end

  def set_dynamite(pos = [AILib.instance.x, AILib.instance.y])
    AILib.instance.set_dynamite(*pos)
    nil
  end

  def set_bomb(pos = [AILib.instance.x, AILib.instance.y])
    AILib.instance.set_bomb(*pos)
    nil
  end

  def set_message(msg)
    AILib.instance.set_message(msg.to_s)
  end

  def turn_over
    AILib.instance.turn_over
    nil
  end

  def map(x, y)
    AILib.instance.map(x, y)
  end

  def map_all
    AILib.instance.map_all
  end

  def locate_objects(args = {})
    AILib.instance.locate_objects(args)
  end

  def other_player_x
    return unless AILib.instance.other_player_pos
    AILib.instance.other_player_pos.first
  end

  def other_player_y
    return unless AILib.instance.other_player_pos
    AILib.instance.other_player_pos.last
  end

  def enemy_x
    return unless AILib.instance.enemy_pos
    AILib.instance.enemy_pos["x"]
  end

  def enemy_y
    return unless AILib.instance.enemy_pos
    AILib.instance.enemy_pos["y"]
  end

  def goal_x
    return unless AILib.instance.goal
    AILib.instance.goal.first
  end

  def goal_y
    return unless AILib.instance.goal
    AILib.instance.goal.last
  end

  def player_x
    AILib.instance.x
  end

  def player_y
    AILib.instance.y
  end
end

class AILib
  include Singleton

  # ゲームサーバのアドレス
  HOST = "127.0.0.1:3000"
  # ラウンドを通してプレイヤーを識別するUUID
  PLAYER_ID = ENV.fetch("SK_PLAYER_ID")
  # プレイヤー1,2のどちらとして登録するか
  PLAYER_SIDE = ENV.fetch("SK_PLAYER_SIDE").to_i
  raise "Invalid PLAYER_SIDE: #{PLAYER_SIDE.inspect}" unless [1, 2].include?(PLAYER_SIDE)
  BLANK_CHIP = {index: 0, weight: 1}
  WALL1_CHIP = {index: 1}
  WALL2_CHIP = {index: 2}
  WATER_CHIP = {index: 4, weight: 2}
  WALL3_CHIP = {index: 5}
  UNCLEARED_CHIP = {index: -1, weight: 4}
  ETC_CHIP = {weight: 3}
  # プレイヤー名の最大長
  PLAYER_NAME_LIMIT = 14
  # サーバに接続できなかった場合のリトライ時間(秒)
  SERVER_RETRY_WAIT = 3
  # サーバへの接続を試みる回数
  SERVER_MAX_TRIES = 20

  attr_accessor :my_map, :x, :y, :goal, :other_player_pos, :enemy_pos, :player_name
  attr_reader :logger

  def initialize
    @my_map = []
    @score = 0
    @x = nil
    @y = nil
    @goal = nil
    @enemy_pos = nil
    @request_count = 0
    @moved = false
    @turn = 1
    @logger = Logger.new($stdout)
  end

  def playGame(&b)
    connectGame(SecureRandom.uuid)
    loop do
      b.call(self)
      AILib.instance.logger.info("行動完了しました: time=#{Time.now.strftime("%H:%M:%S")}")
      turn_over
      AILib.instance.logger.info("ターンを終了しました: time=#{Time.now.strftime("%H:%M:%S")}")
    end
  end

  def connectGame(game_code = nil)
    raise "プレイヤー名を付けてください（最大#{PLAYER_NAME_LIMIT}文字まで）" unless @player_name
    raise "プレイヤー名が長すぎます（最大#{PLAYER_NAME_LIMIT}文字までで命名してください）" if @player_name.size > PLAYER_NAME_LIMIT

    game_code ||= SecureRandom.uuid
    url = URI.parse("http://#{HOST}/api/manage/connectGame")
    req = Net::HTTP::Post.new(url.path)
    req["Content-Type"] = "application/json"
    req.body = {"code" => game_code, "name" => @player_name, "uuid" => PLAYER_ID, "side" => PLAYER_SIDE}.to_json

    http = Net::HTTP.new(url.host, url.port)
    http.read_timeout = nil
    tries = 0
    begin
      tries += 1
      res = http.start { http.request(req) }
    rescue Errno::ECONNREFUSED
      if tries >= SERVER_MAX_TRIES
        AILib.instance.logger.error("ゲームサーバへの接続に失敗しました。")
        exit 1
      else
        AILib.instance.logger.error("ゲームサーバが起動していません。#{SERVER_RETRY_WAIT}秒後に再接続します")
        sleep SERVER_RETRY_WAIT
        retry
      end
    end
    result = JSON.parse(res.body)
    update_player_info(result)
    result
  end

  # 指定した位置(絶対座標)に移動する
  def move_to(x, y)
    return nil if !check_request_count("moveTo", x, y)
    if @moved
      AILib.instance.logger.warn("このターンではもう移動できません")
      return nil
    end
    res = Net::HTTP.post_form(
      URI.parse("http://#{HOST}/api/move/to"),
      {"x" => x, "y" => y, "uuid" => PLAYER_ID}
    )
    result = check_api_response("moveTo", res)
    @request_count += 1
    @moved = true
    result
  end

  def get_map_area(x, y)
    return nil if !check_request_count("getMapArea", x, y)
    uri = URI.parse("http://#{HOST}/api/search/getMapArea")
    uri.query = URI.encode_www_form({x: x, y: y, uuid: PLAYER_ID})
    res = Net::HTTP.get_response(uri)
    result = check_api_response("getMapArea", res)
    @request_count += 1
    update_player_info(result)
    result
  end

  def set_dynamite(x, y)
    return nil if !check_request_count("setDynamite", x, y)
    res = Net::HTTP.post_form(
      URI.parse("http://#{HOST}/api/move/setDynamite"),
      {"x" => x, "y" => y, "uuid" => PLAYER_ID}
    )
    result = check_api_response("setDynamite", res)
    @request_count += 1
    result
  end

  def set_bomb(x, y)
    return nil if !check_request_count("setBomb", x, y)
    res = Net::HTTP.post_form(
      URI.parse("http://#{HOST}/api/move/setBomb"),
      {"x" => x, "y" => y, "uuid" => PLAYER_ID}
    )
    result = check_api_response("setBomb", res)
    @request_count += 1
    result
  end

  MAX_MSG_LEN = 100
  def set_message(msg)
    # 大きすぎるデータ(1MBとか)が送信されないようにする
    msg = msg[0, MAX_MSG_LEN]
    AILib.instance.logger.info("set_messageを実行します msg=#{msg}")
    res = Net::HTTP.post_form(
      URI.parse("http://#{HOST}/api/move/setMessage"),
      {"msg" => msg, "uuid" => PLAYER_ID}
    )
    check_api_response("setMessage", res)
  end

  def turn_over
    AILib.instance.logger.info("turnOverを実行します turn=#{@turn}")
    res = Net::HTTP.post_form(
      URI.parse("http://#{HOST}/api/manage/turnOver"),
      {"uuid" => PLAYER_ID}
    )
    result = JSON.parse(res.body)
    update_player_info(result[PLAYER_ID])
    case result[PLAYER_ID]["status"]
    when "completed"
      AILib.instance.logger.info("ゴールしました!")
      exit 0
    when "timeout"
      AILib.instance.logger.info("タイムアウトしました")
      exit 0
    when "timeup"
      AILib.instance.logger.info("ゴールできませんでした")
      exit 0
    end
    @turn += 1
    @request_count = 0
    @moved = false
    result
  end

  def map(x, y)
    if @my_map && @my_map[y]
      return @my_map[y][x]
    end
    nil
  end

  def map_all
    @my_map
  end

  # 2点間の移動経路を[[x, y], ...]形式で返す
  #
  # src: [x, y] 始点(省略時はプレイヤーの現在座標)
  # dst: [x, y] 終点(省略時はゴール地点)
  # except_cells: [[x1, y1], ...] 通りたくない場所(省略可)
  def calc_route(args = {})
    if args[:src] &&
        (!args[:src].is_a?(Array) || args[:src].size != 2)
      raise "calc_route の src は「[x, y]」の形式で指定してください。" \
        " src=<#{args[:src].inspect}>"
    end
    if args[:dst] &&
        (!args[:dst].is_a?(Array) || args[:dst].size != 2)
      raise "calc_route の dst は「[x, y]」の形式で指定してください。" \
        " dst=<#{args[:dst].inspect}>"
    end
    if args[:except_cells] &&
        (!args[:except_cells].is_a?(Array) ||
         !args[:except_cells].all? { |point| point.is_a?(Array) && point.size == 2 })
      raise "calc_route の except_cells は「[[x1, y1], [x2, y2], ...]」の形式で指定してください。" \
        " except_cells=<#{args[:except_cells].inspect}>"
    end
    src_x, src_y = args[:src] || [@x, @y]
    dst_x, dst_y = args[:dst] || @goal
    except_cells = args[:except_cells] || []
    data = make_data(@my_map.map { |i| i.dup }, except_cells)
    g = DijkstraSearch::Graph.new(data)
    sid = "m#{src_x}_#{src_y}"
    gid = "m#{dst_x}_#{dst_y}"
    g.get_route(sid, gid)
  end

  # 特定アイテムが存在する地点を列挙する
  # 調査範囲はcentを中央とする幅・高さsq_sizeの正方形
  #
  # sq_size: 1..15の奇数 調査範囲(省略時は5)
  # cent: [x, y] 調査する中央座標(省略時はプレイヤー現在地)
  # objects: [item1, ...] 調査対象(省略時はA, B, C, D)
  def locate_objects(args = {})
    if args[:sq_size] &&
        (!args[:sq_size].is_a?(Integer) ||
         args[:sq_size] < 1 || args[:sq_size] > 17 ||
         args[:sq_size] % 2 == 0)
      raise "locate_objects の sq_size は1以上15以下の奇数を指定してください。" \
        " sq_size=<#{args[:sq_size].inspect}>"
    end
    if args[:cent] &&
        (!args[:cent].is_a?(Array) || args[:cent].size != 2)
      raise "locate_objects の cent は「[x, y]」の形式で指定してください。" \
        " cent=<#{args[:cent].inspect}>"
    end
    if args[:objects] && !args[:objects].is_a?(Array)
      raise "locate_objects の objects は「[item1, item2, ...]」の形式で指定してください。" \
        " objects=<#{args[:objects].inspect}>"
    end
    sq_size = args[:sq_size] || 5
    cent_x, cent_y = args[:cent] || [@x, @y]
    sq_length = (sq_size - 1) / 2
    objects = args[:objects] || ["A", "B", "C", "D"]
    location = []
    sq_size.times do |dy|
      y = dy - sq_length + cent_y
      next if y < 0 || y >= @my_map.size
      sq_size.times do |dx|
        x = dx - sq_length + cent_x
        next if x < 0 || x >= @my_map.first.size
        if objects.include?(@my_map[y][x])
          location << [x, y]
        end
      end
    end

    location
  end

  private

  # DijkstraSearchのためのグラフ構造を返す
  def make_data(map, except_cells)
    except_cells.each do |cell|
      ex, ey = cell
      map[ey][ex] = WALL1_CHIP[:index]
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

  def update_player_info(info)
    info = JSON.parse(info) if info.is_a?(String)
    return nil unless info
    @goal = info["goal"] if info["goal"]
    @my_map = info["map"] if info["map"]
    @x = info["x"].to_i if info["x"]
    @y = info["y"].to_i if info["y"]
    @other_player_pos = info["other_player"] if info.has_key?("other_player")
    @enemy_pos = info["enemy"] if info.has_key?("enemy")
  end

  def check_request_count(method_name, *args)
    s = "#{method_name}を実行します"
    s += " 引数=#{args.inspect}" if args.length > 0
    AILib.instance.logger.debug(s)
    if @request_count >= 2
      AILib.instance.logger.warn("このターンはもう行動できません count=#{@request_count}")
      return false
    end
    true
  end

  def check_api_response(method, res)
    result = JSON.parse(res.body)
    s = {
      "moveTo" => "移動",
      "getMapArea" => "マップ情報の取得",
      "setDynamite" => "ダイナマイトの設置",
      "setBomb" => "爆弾の設置",
      "setMessage" => "発言"
    }[method]
    case res
    when Net::HTTPClientError, Net::HTTPServerError
      AILib.instance.logger.error("#{s}に失敗しました message=#{result["message"]}")
    end
    result
  end
end

AILib.instance.logger.info("")
AILib.instance.logger.info("")
AILib.instance.logger.info("--- AIライブラリを読み込みました ---")
AILib.instance.logger.info("乱数シード: #{seed}") if ENV["SK_RANDOM_SEED"]

at_exit do
  # 例外をloggerを使って記録する

  Smalruby.start if Object.const_defined?(:Smalruby)
rescue => ex
  AILib.instance.logger.error("エラーが発生しました (#{ex.class}) #{ex.message}")
  ex.backtrace.each do |line|
    # AIのファイル名が日本語だった場合のためにencodeしている
    AILib.instance.logger.error(line.encode("utf-8", "cp932"))
  end
end
