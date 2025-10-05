module Smalruby3
  class Koshien::Map
    attr_accessor :map

    def initialize(map = nil)
      case map
      when String
        @map = map.split(",").map { |x| x.chars.map { |xy| (xy == "-") ? -1 : xy.to_i } }
      when Array
        @map = map
      end
    end

    def data(position)
      return -1 unless @map
      return -1 if @map.empty?
      return -1 if position.y < 0 || position.y >= @map.length
      return -1 if position.x < 0 || !@map[position.y] || position.x >= @map[position.y].length

      @map[position.y][position.x]
    end

    def to_s
      @map.map { |x| x.map { |xy| (xy == -1) ? "-" : xy.to_s }.join("") }.join(",")
    end

    def to_a
      @map
    end
  end
end
