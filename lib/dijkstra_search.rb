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
      @res = [base]
      while (base = @nodes.find { |node| node.id == base.from })
        @res << base
      end
      @res
    end

    # 二点間の最短経路を座標の配列で返す
    # sid : 始点のID
    # gid : 終点のID
    def get_route(sid, gid)
      route(sid, gid)
      @res.reverse.map { |node|
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
