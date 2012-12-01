#!/usr/bin/ruby

require 'gtk2'

# 非矩形クラス
class ShapedWindow < Gtk::Window
  include Math


  # コンストラクタ
  def initialize(image)
    super(Gtk::Window::TOPLEVEL)

    self.keep_above = true

    load_image(image)

    # 再描画が必要なときに発行されるシグナル
    # 初めに起動したときにも発行される
    signal_connect("expose-event") do 
      # cairoで扱うコンテキストをwindowから取得
      cc = self.window.create_cairo_context
      # コンテキストを元に表示
      draw(cc)
      true
    end
  end


  # 画像をロードし、ウインドウサイズを画像に合わせる
  def load_image(image)
    @pixbuf = Gdk::Pixbuf.new(image)
    @w = @pixbuf.width
    @h = @pixbuf.height
    
    self.set_default_size(@w, @h)
    self.set_shape_mask
  end

  
  # 透過処理
  def set_shape_mask
    bitmap = Gdk::Pixmap.new(nil, @w, @h, 1)
    cc = bitmap.create_cairo_context
    draw(cc)
    
    self.shape_combine_mask(bitmap, 0, 0)
  end
  
  # 描画する
  def draw(cc)

    # 背景をクリアする
    cc.operator = Cairo::OPERATOR_CLEAR
    cc.paint

    # 画像を描画する
    cc.operator = Cairo::OPERATOR_SOURCE
    cc.antialias = Cairo::ANTIALIAS_SUBPIXEL
    cc.set_source_pixbuf(@pixbuf)
    cc.paint
  end
end


# 吹き出し
class Balloon < ShapedWindow

  # テキストを表示しやすいように分割する
  def extract_text(cc, text)
    result = []
    tmp = ""

    text.each_char { |char|
      # 描画した時の幅を取得
      txext = cc.text_extents( tmp + char );

      # 吹き出しからはみ出す場合は改行する
      if txext.width > 300 then
        result << tmp
        tmp = char
      else
        tmp = tmp + char
      end
    }

    # 余りを最終行に
    if !tmp.empty? then
      result << tmp
    end

    result
  end


  # コンストラクタ
  def initialize(owner, image_l, image_r, text)
    @image_l = image_l
    @image_r = image_r
    @owner = owner
    @text = text
    @row = 0
    @start = 0
    @pointer = 0
    @extracted_text = nil
    @signal = nil
    @is_left = false

    super(image_l)

    # 親ウインドウのサイドに移動する
    self.move(@owner.position[0] + @owner.size[0], (@owner.size[1] - self.size[1]) / 2 + @owner.position[1])

    # 親ウインドウがクリックされた
    @signal = @owner.signal_connect("configure-event") { |owner, event|
   
      # 画面右に吹き出し表示スペースがない
      if (!@is_left || ((@owner.position[0] + @owner.size[0]) + self.size[0] > screen.width)) then
        # 親ウインドウの左サイドに移動する
        load_image(@image_r)
        self.move(owner.position[0] - self.size[0], (event.height - self.size[1]) / 2 + event.y)

        @is_left = false
      end

      # 画面左に吹き出し表示スペースがない
      if (@is_left || (@owner.position[0] < self.size[0])) then
        # 親ウインドウの右サイドに移動する
        load_image(@image_l)
        self.move(event.x + event.width, (event.height - self.size[1]) / 2 + event.y)

        @is_left = true
      end

      true
    }

    signal_connect("destroy") {
      @owner.signal_handler_disconnect(@signal)
    }

    # メッセージを1文字ずつ表示する
    GLib::Timeout.add(100){
      if @extracted_text == nil then
        next true
      end

      @pointer = @pointer + 1
      
      if @pointer >= @extracted_text[@row].length then
        @row = @row + 1
        @pointer = 0

        if @row - @start == 5 then
          @start = @start + 1
        end

        # 表示完了
        if @row == @extracted_text.length 

          # ちょっとしたらウインドウを消す
          GLib::Timeout.add(3000){
            self.destroy
            false
          }

          next false
        end
      end

      # ウインドウ描画
      self.queue_draw

      true
    }
  end


  # 描画する
  def draw(cc)
    # 親クラスに背景を描かせる
    super(cc)

    # メッセージの表示
    cc.antialias = Cairo::ANTIALIAS_SUBPIXEL
    cc.set_source_rgb(0.3,0.3,0.3)
    cc.font_size = 16
    cc.move_to(16, 22)

    # テキストを表示しやすいように分割する
    # （ウインドウ表示中かつコンテキストが有る時に呼び出す必要がある。）
    if @extracted_text == nil then
      @extracted_text = extract_text(cc, @text)
    end

    # 表示済みの行を一気に描画
p @start
p @row
p @extracted_text[@row]
p ""
    (0..(@row - @start) - 1).each { |i|
      cc.show_text(@extracted_text[@start + i])
      cc.move_to(16, 22 + (16 * (i + 1)))
    }

    # 表示すべき文字まで描画
    if @extracted_text[@row] != nil then
     cc.show_text(@extracted_text[@row][0..@pointer])
    end
  end
end


# としぁさんを落下させる
def fall_toshi_a(toshi_a, &block)
  i = 0

  GLib::Timeout.add(50){
    toshi_a.move(32, i)
    toshi_a.show

    i = i + 20

    if i > (Gdk::screen_height - toshi_a.size[1] ) then
      toshi_a.move(32, (Gdk::screen_height - toshi_a.size[1] ))

      block.call(toshi_a)

      false
    else
      true
    end
  }
end


# てすと
shape = ShapedWindow.new("surface10.png")

fall_toshi_a(shape) { |toshi_a|
  GLib::Timeout.add(500){
    balloon = Balloon.new(toshi_a ,"balloonk1.png","balloonk0.png","This is test..............................asd1234567890asdsdadsdaxxxa................................................abcdefghijklmnopqrstuvwxyg12345678901234567890ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890abcdefghijklmnopqrstuvwxyz")
    balloon.show

    false
  }
}


Gtk::main()
