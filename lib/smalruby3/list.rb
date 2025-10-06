module Smalruby3
  class List
    def initialize(values = [])
      @array = Array.new(values)
    end

    # list("$リスト").push("なにか")
    def push(val)
      @array.push(val)
    end

    # list("$リスト").delete_at(1)
    def delete_at(list_index)
      @array.delete_at(to_array_index(list_index: list_index))
    end

    # list("$リスト").clear
    def clear
      @array.clear
    end

    # list("$リスト")[1] = "なにか"
    def []=(list_index, val)
      @array[to_array_index(list_index: list_index)] = val
    end

    # list("$リスト").insert(1, "なにか")
    def insert(list_index, val)
      @array.insert(to_array_index(list_index: list_index), val)
    end

    # list("$リスト")[1]
    def [](list_index)
      @array[to_array_index(list_index: list_index)]
    end

    # list("$リスト").index("なにか")
    def index(val)
      to_list_index(array_index: @array.index(val))
    end

    # list("$リスト").length
    def length
      @array.length
    end

    # list("$リスト").include?("なにか")
    def include?(val)
      @array.include?(val)
    end

    def replace(array)
      @array.replace(array)
    end

    def map(&block)
      @array.map(&block)
    end

    def each(&block)
      @array.each(&block)
    end

    def to_s
      @array.map(&:to_s).join
    end

    private

    # ‐ 0はエラー
    # - 1以上は1を引く
    # - -1以下はそのまま
    def to_array_index(list_index:)
      raise ArgumentError, "リストの何番目には1以上の整数、または-1以下の整数を指定してください" if list_index == 0

      return list_index - 1 if list_index >= 1

      list_index
    end

    # - 0以上は1を足す
    # - -1以下はそのまま
    # - nilはnilのまま
    def to_list_index(array_index:)
      return nil if array_index.nil?
      return array_index + 1 if array_index >= 0

      array_index
    end
  end
end
