# 以下のようなAI実装に対し、Smalrubyウィンドウを表示させずに動作させるためのパッチ
# ai_lib経由でAI本体の実行前に読み込まれる
#
#   require "smalruby"
#
#   cat1 = Character.new(costume: "cat1.png", x: 200, y: 200, angle: 0)
#   require_relative 'lib/ai_lib'
#   ...
#
# TODO: 将来的には、Smalruby::Consoleクラスを直接使う方向で解決する

if Object.const_defined?(:Smalruby)
  module Smalruby
    class Console < Character
      module Patch
        # 引数を渡しても無視するようにする
        def initialize(*args)
          super()
        end
      end
      prepend Patch
    end

    remove_const :Character
    Character = Console
  end
end
