#!/usr/bin/ruby
# -*- coding: utf-8 -*-

require 'gtk2'
# 非矩形クラス
class ShapedWindow < Gtk::Window
  include Math


  # コンストラクタ
  def initialize(image)
    super(Gtk::Window::TOPLEVEL)

    self.type_hint = Gdk::Window::TYPE_HINT_SPLASHSCREEN

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
      # 改行
      if char == "\n" then
        result << tmp
        tmp = ""
      else
        # 描画した時の幅を取得
        txext = cc.text_extents( tmp + char );

        # 吹き出しからはみ出す場合は改行する
        if txext.width > 300 then
          result << tmp
          tmp = char
        else
          tmp = tmp + char
        end
      end
    }

    # 余りを最終行に
    if !tmp.empty? then
      result << tmp
    end

    result
  end


  # メッセージを描画する
  def message(text)
    @pointer = 0
    @start = 0
    @row = 0
    @text = text

    self.show

    cc = self.window.create_cairo_context
    cc.antialias = Cairo::ANTIALIAS_SUBPIXEL
    cc.set_source_rgb(0.3,0.3,0.3)
    cc.font_size = 14
    cc.select_font_face("Sans", Cairo::FONT_SLANT_NORMAL, Cairo::FONT_WEIGHT_NORMAL);

    @extracted_text = extract_text(cc, @text)

    # メッセージを1文字ずつ表示する
    while true do
      pointer = @pointer + 1
      start = @start
      row = @row
      
      if @pointer >= @extracted_text[@row].length then
        row = row + 1
        pointer = 0

        if row - start == 4 then
          start = start + 1
        end

        # 表示完了
        if row == @extracted_text.length 
          break
        end
      end

      @pointer = pointer
      @start = start
      @row = row

      # ウインドウ描画
      self.queue_draw()

      sleep(0.1)
    end
  end


  # コンストラクタ
  def initialize(owner, image_l, image_r)
    @image_l = image_l
    @image_r = image_r
    @owner = owner
    @text = ""
    @row = 0
    @start = 0
    @pointer = 0
    @extracted_text = nil
    @signal = nil
    @is_left = false

    super(image_l)

    # 画面右に吹き出し表示スペースがない
    if (!@is_left || ((@owner.position[0] + @owner.size[0]) + self.size[0] > screen.width)) then
      # 親ウインドウの左サイドに移動する
      load_image(@image_r)
      self.move(owner.position[0] - self.size[0], (owner.size[1] - self.size[1]) / 2 + owner.position[1])

      @is_left = false
    end

    # 画面左に吹き出し表示スペースがない
    if (@is_left || (@owner.position[0] < self.size[0])) then
      # 親ウインドウの右サイドに移動する
      load_image(@image_l)
      self.move(owner.position[0] + owner.size[0], (owner.size[1] - self.size[1]) / 2 + owner.position[1])

      @is_left = true
    end

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

      false
    }

    signal_connect("destroy") {
      @owner.signal_handler_disconnect(@signal)
    }

  end


  # 描画する
  def draw(cc)
    # 親クラスに背景を描かせる
    super(cc)

    # メッセージの表示
    cc.antialias = Cairo::ANTIALIAS_SUBPIXEL
    cc.set_source_rgb(0.3,0.3,0.3)
    cc.font_size = 14
    cc.select_font_face("Sans", Cairo::FONT_SLANT_NORMAL, Cairo::FONT_WEIGHT_NORMAL);
    cc.move_to(16, 22)

    if @extracted_text == nil then
      return 
    end

    # 表示済みの行を一気に描画
    (0..(@row - @start) - 1).each { |i|
      cc.show_text(@extracted_text[@start + i])
      cc.move_to(16, 22 + ((16 + 2) * (i + 1)))
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


# としぁさんの一挙手一投足を検索するクラス
class Toshi_a
  attr_reader :last_fetch_time


  def initialize(service)
    @service = service
    @queue_lock = Mutex.new
    @result_queue = []
  end


  # 日時文字列をパースする
  def parse_time(str)
    begin
      if str.class == Time then
        str
      else
        Time.parse(str)
      end
    rescue
      nil
    end
  end


  # 検索結果を取り出す
  def fetch()
    msg = nil

    @queue_lock.synchronize {
      msg = @result_queue.shift
    }

    if msg != nil then
      @last_fetch_time = Time.now
    end 

    # puts @keywords.to_s + @result_queue.size.to_s

    return msg
  end


  # メッセージ保有してる？
  def empty?()
   @result_queue.empty?
  end


  # 検索する
  def search()
    keyword = "toshi_a"

    query_keyword = keyword.strip.rstrip.sub(/ +/,"+")
  
    if query_keyword.empty? then
      return
    end
  
    params = {}

    query_tmp = query_keyword + "+-rt+-via"

    if @last_result_time != nil then
      query_tmp = query_tmp + "+since:" + @last_result_time.strftime("%Y-%m-%d")
    end
  
    params[:q] = query_tmp

    params[:rpp] = 500.to_s

    if query_keyword.empty? then
      return
    end
  
    params[:lang] = "ja"

    @service.search(params).next{ |res| 
      begin
        res = res.select { |es|
          result_tmp = false

          if es[:created_at].class == String then
            tim = parse_time(es[:created_at]) 
          else
            p "mulformed created_at:"
            p es.class
            p es

            tim = nil
          end

          reply = es.receive_message

          if !(es[:message] =~ /^RT /) then
            result_tmp2 = false

            if es[:user] != nil then
              if es[:user][:idname] == "toshi_a"
                result_tmp2 = true
              end

              if result_tmp2 then
                if @last_result_time == nil then
                  result_tmp = true
                elsif tim != nil && @last_result_time < tim then
                  result_tmp = true
                end
              end
            end
          end

          result_tmp
        }

        if res.size == 0 then
          next
        end
  
        res.each { |es| 
          # 一回アクセスしてキャッシュさせる
          reply = es.receive_message

          tim = parse_time(es[:created_at])
  
          if tim != nil && (@last_result_time == nil || @last_result_time < tim) then
            @last_result_time = tim
          end
        }
  
        # p "new message:" + res.size.to_s
        # p "last time:" + $last_time.to_s
  
        @queue_lock.synchronize {
          # puts @keywords.to_s + res.size.to_s
          @result_queue.concat(res.reverse)
        }
      rescue => e
        puts e
        puts e.backtrace
      end
    }
  end
end
  

Plugin.create :toshi_a_talk do 
  
  # グローバル変数の初期化
  $toshi_a = nil


  # 検索用ループ
  def search_loop(service)
    search_keyword(service) 

    Reserver.new(UserConfig[:toshi_a_talk_period]){
      search_loop(service)
    } 
  end
  

  # 混ぜ込みループ
  def insert_loop(service)
    begin
      if !$toshi_a.empty? then
        msg = $toshi_a.fetch

        $talk_queue << msg

        if $charactor_thread.stop? then
          $charactor_thread.wakeup
        end
      end

      Reserver.new(UserConfig[:toshi_a_talk_insert_period]){
        insert_loop(service)
      } 
        
    rescue => e
      puts e
      puts e.backtrace
    end
  end


  # 検索
  def search_keyword(service)
    begin
      $toshi_a.search()
    rescue => e
      puts e
      puts e.backtrace
    end
  end


  # 起こされても起きない
  def please_sleep(sec)
    sleep_sec = sec

    while true do
      # 残り時間分sleep
      sleep_sec = sleep_sec - sleep(sleep_sec)
     
      if sleep_sec <= 0.0 then
        break
      end
    end
  end


  # としぁさん大暴れ！スレッド
  def charactor_thread(charactor, balloon_toshi_a, balloon_miku, queue)
    while true
      # キューを待つ
      Thread.stop

      while !queue.empty?
        msg = queue.shift

        reply = msg.receive_message 

        if reply != nil then
          balloon_miku.message("としぁさん。" + reply[:user][:name] + "さんがこんなこと言ってたよ。" + "\n\n" + reply[:message])
          please_sleep(0.5)
        end

        balloon_toshi_a.message(msg[:message])
        please_sleep(3)

        balloon_toshi_a.hide
        balloon_miku.hide

        please_sleep(5)        
      end
    end
  end


  # 起動時処理
  on_boot do |service|
    $toshi_a = Toshi_a.new(service)

    # コンフィグの初期化
    UserConfig[:toshi_a_talk_period] ||= 60
    UserConfig[:toshi_a_talk_insert_period] ||= 20

    # 設定画面
    settings "おしゃべりとしぁさん" do
      adjustment("ポーリング間隔（秒）", :toshi_a_talk_period, 1, 6000)
      adjustment("混ぜ込み間隔（秒）", :toshi_a_talk_insert_period, 1, 600)
    end 

    search_loop(service)
    insert_loop(service)
  end


  # 起動時処理(for 0.2)
  on_window_created do |i_window|
    $talk_queue = []

    # メインウインドウを取得
    window_tmp = Plugin.filtering(:gui_get_gtk_widget,i_window)

    if (window_tmp == nil) || (window_tmp[0] == nil) then
      next
    end

    mikutter_window = window_tmp[0]

    dir = File.dirname(__FILE__)

    # としぁさん登場
    $charactor = ShapedWindow.new(dir + "/surface10.png")
    $charactor.move(32, (Gdk::screen_height - $charactor.size[1] ))
    $charactor.show

    # 吹き出し登場
    $balloon_toshi_a = Balloon.new($charactor, dir + "/balloonk1.png", dir + "/balloonk0.png")
    $balloon_mikutter = Balloon.new(mikutter_window, dir + "/balloonk1.png", dir + "/balloonk0.png")

    # としぁさんをメインスレッドの呪縛から解放する
    $charactor_thread = Thread.new {
      # メインスレッドさんに逆らうと更新がリアルタイムで行われないから自重する。
      $charactor_thread.priority = 1

      begin
        charactor_thread($charactor, $balloon_toshi_a, $balloon_mikutter, $talk_queue)
      rescue => e
        puts e
        puts e.backtrace
      end
    }
  end
end


# てすと
def test
  shape = ShapedWindow.new("surface10.png")

  fall_toshi_a(shape) { |toshi_a|
    GLib::Timeout.add(500){
      balloon = Balloon.new(toshi_a ,"balloonk1.png","balloonk0.png","48枚もの16GB DIMMを搭載し、768GBという大容量メモリを実現したハイエンドサーバーがPC DIY SHOP FreeTで展示中だ。\n\n 停止状態で展示されているが、実際に動作させることも可能という。
\n")
#    balloon = Balloon.new(toshi_a ,"balloonk1.png","balloonk0.png","This is test\n..............................asd1234567890asdsdadsdaxxxa................................................abcdefghijklmnopqrstuvwxyg12345678901234567890ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890abcdefghijklmnopqrstuvwxyz")
      balloon.show

      false
    }
  }

  Gtk::main()
end


