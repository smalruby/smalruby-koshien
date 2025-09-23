module Smalruby3
  # 座標を表現するクラス
  # 文字列形式 "<x>:<y>"、配列形式 [x, y]、x座標とy座標を個別に取得するx, yを実現する。
  class Koshien::Position
    attr_accessor :x
    attr_accessor :y

    def initialize(x_or_position = nil, y = nil)
      case x_or_position
      when self.class
        @x, @y = *x_or_position.to_a
      when String
        @x, @y = *x_or_position.split(":").map(&:to_i)
      when Array
        @x, @y = *x_or_position
      else
        @x = x_or_position
      end
      @y = y if y
    end

    # "x:y"形式の座標を返す
    def to_s
      "#{x}:#{y}"
    end

    # 配列 [x, y] の座標を返す
    def to_a
      [x, y]
    end
  end
end
