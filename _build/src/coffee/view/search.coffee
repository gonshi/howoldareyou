EventDispatcher = require( "../util/eventDispatcher" )

ticker = require( "../util/ticker" )()
instance = null

class Search extends EventDispatcher
  constructor: ->
    super()
    @$win = $( window )

    @$search_container = $( ".search_container" )
    @$search = @$search_container.find( ".search" )
    @$enter = @$search_container.find( ".enter" )

    # result
    @$result_container = $( ".result_container" )
    @$result = @$result_container.find( ".result" )
    @$portrait = @$result.find( ".portrait" )
    @$name = @$result.find( ".name" )
    @$episode = @$result.find( ".episode" )
    @$age_num = @$result.find( ".age_container .num" )
    @$link = @$result.find( ".link" )

    # year
    @$year_container = $( ".year_container" )
    @$year_bar = $( ".year_bar" )
    @$year = @$year_container.find( ".year" )
    @$pin = @$year_container.find( ".pin" )
    @YEAR_WIDTH = parseInt( @$year.eq( 1 ).css "left" ) / 10 # ten year
    @PIN_WIDTH = parseInt @$pin.width()

    # portrait container (introのアニメーションのため、
    # 背景のportraitにもアクセスできるようにする)
    @$portrait_container = $( ".portrait_container" )

    # values
    @portrait_loaded = []
    @cur_year_left = 0
    @RESULT_PADDING_HEIGHT = 247
    @ESCAPE_KEYCODE = 27
    @WIKI_LINK_ORIGIN = "https://ja.wikipedia.org/wiki/"
    @win_width = null

    # sound
    @roulette_sound = new Audio()
    @roulette_sound.src = "audio/roulette.mp3"
    @roulette_sound.volume = 0.2

    @open_sound = new Audio()
    @open_sound.src = "audio/open.mp3"

    @close_sound = new Audio()
    @close_sound.src = "audio/close.mp3"

    # loaded portrait count (for intro)
    @loaded_portrait_num = 0

  diffusePortrait: ( diffuse_num )-> # introページでportrait画像をばら撒く演出
    _result_rect = @$result.get( 0 ).getBoundingClientRect()

    _portrait_row_width =
      @$portrait_container.find( ".portrait_row" ).width()

    for i in [ 0...diffuse_num ]
      loop
        if i == 0
          _i = diffuse_num - 1
        else
          _i = Math.floor( Math.random() * @$portrait.find( "img" ).size() )
        break unless @$portrait.find( "img" ).eq( _i ).hasClass "selected"

      _$portrait = @$portrait.find( "img" ).eq _i
      _$portrait.addClass "selected"
      _portrait_id = _$portrait.attr( "data-id" )

      loop # ランダムに、かつ未選択のターゲットportrait(背景側のportrait)を選ぶ
        _rand = (
          Math.floor(
            Math.random() * @$portrait_container.
            find( ".portrait_pic_#{ _portrait_id }" ).
            size()
          )
        )

        _targetPortrait =
          @$portrait_container.
          find( ".portrait_pic_#{ _portrait_id }" ).
          get _rand

        break unless _targetPortrait.className.match "selected"

      _targetPortrait.className += " selected" # 選ばれたものにはチェックをつける

      do (_$portrait, _targetPortrait)->
        if skip
          _dur = 0
          _delay = 0
        else
          _dur = DUR * 6
          _delay = 10 * i

        if $( _targetPortrait ).parents( ".portrait_row" ).index() % 2 == 0
          _vec = -1
        else
          _vec = 1

        _target_left =
          _targetPortrait.getBoundingClientRect().left +
          _portrait_row_width / 2 / 150 *
          ( ( _dur + _delay ) / 1000 ) * _vec
          # 150: transition sec, 2: duration sec

        _target_top = _targetPortrait.getBoundingClientRect().top

        if _target_left + _targetPortrait.offsetWidth > _result_rect.left &&
           _target_left < _result_rect.right &&
           _target_top + _targetPortrait.offsetHeight > _result_rect.top &&
           _target_top < _result_rect.bottom
          _target_opacity = 0.02 # 移動先がモーダルの裏に隠れている場合、その明度に合わせる
        else
          _target_opacity = 0.2

        # モーダル上の位置から、背景側の
        # 同一ポートレートの位置までアニメーションさせる
        _$portrait.css
          position: "fixed"
          top: _$portrait.get( 0 ).getBoundingClientRect().top
          left: _$portrait.get( 0 ).getBoundingClientRect().left
          width: _$portrait.width()
          height: _$portrait.height()
        .velocity # 横位置
          left: _target_left
          width: _targetPortrait.offsetWidth
          height: _targetPortrait.offsetHeight
          opacity: [ _target_opacity, 0 ]
        ,
          duration: _dur
          delay: _delay
          easing: "easeOutSine"
          complete: ->
            _$portrait.remove()
            _targetPortrait.className += " show"

        _$portrait.velocity top: _target_top # 縦位置
        ,
          duration: _dur
          delay: _delay
          easing: "easeInSine"
          queue: false

  setEpisode: ( episode )->
    @episode = episode
    @origin_episode = $.extend true, {}, episode

  setPortrait: ( src, img_num )-> # introページのportraitをモーダル上にappendしていいく
    return unless src

    _pic = new Image()
    _pic.src = src
    _pic.setAttribute "data-id", img_num

    for i in [ 0...2 ] # 背景側も、スライド用に各画像2枚ずつあるので、こちらでも2枚ずつ置いていく
      @$portrait.append $( _pic ).clone()
      @loaded_portrait_num += 1

      if @loaded_portrait_num == Math.floor( @PORTRAIT_MAX / 3 )
        # 読み込み終えたことをチェックする。tickerのTIMER_FROM_STARTで
        # この値を監視し、trueであれば(画像用意が完了していれば)diffuseイベントを開始させる
        @portrait_loaded[ 0 ] = true
      else if @loaded_portrait_num == Math.floor( @PORTRAIT_MAX * 2 / 3 )
        @portrait_loaded[ 1 ] = true
      else if @loaded_portrait_num == @PORTRAIT_MAX
        @portrait_loaded[ 2 ] = true

  dropPin: ( year )->
    # 年号アニメーション & ピン落とす
    @$pin.css
      left: @YEAR_WIDTH * year - @PIN_WIDTH / 2
      opacity: 0

    _next_year_left = @win_width / 2 -
                      @$pin.get( 0 ).getBoundingClientRect().left +
                      @cur_year_left

    @$year_bar.velocity # 該当位置までバーをスライドさせる
      translateX: _next_year_left
    , DUR * 2, =>
      @cur_year_left = _next_year_left

      @$pin.velocity
        opacity: [ 1, 0 ]
        translateY: [ 0, -20 ]
      , DUR, [ 200, 10 ], => @$result_container.removeClass "is_animating"

  search: ( age )->
    return if @search_interval

    @open_sound.currentTime = 0
    @open_sound.play()

    @search_interval = setInterval => # 連打防止
      if @episode?
        clearInterval @search_interval
        @search_interval = null

        if !@episode[ age ]?
          alert "該当する人物なし"
          return

        _id = Math.floor( Math.random() * @episode[ age ].length )
        @showResult age, @episode[ age ][ _id ].id

        @episode[ age ].splice _id, 1 # 同じ人が連続で出ないようにする

        if @episode[ age ].length == 0
          @episode[ age ] = $.extend true, [], @origin_episode[ age ]
    , 200

  setPortraitMax: ( num )-> @PORTRAIT_MAX = num

  showIntro: ->
    @$result_container.removeClass( "withoutPortrait" ).addClass "is_animating"

    @$name.text "ここに出てくる偉人はみんな"
    @$name.css fontSize: 28
    @$result.find( ".name_particle" ).hide() # "は(助詞)" を消す

    @$result_container.show().velocity opacity: [ 1, 0 ], DUR, =>
      @$result_container.removeClass "is_animating"

      @roulette_sound.play()
      ticker.listen "AGE_COUNTUP", ( t )=>
        _age = Math.floor( t / 30 )
        if _age > 0
          ticker.clear "AGE_COUNTUP"
          @roulette_sound.pause()
          @roulette_sound.currentTime = 0
        else
          @$age_num.text _age

    _wait_span = if skip then 0 else 8000

    ticker.listen "TIMER_FROM_START", ( t )=>
      for i in [ 0...3 ]
        if t > _wait_span * i  # _wait_span(ms) 置きにdiffuseイベントを発生させる
          if @portrait_loaded[ i ] # ロードが完了したタイミングで
            if i == 1 && @portrait_loaded[ 0 ] != null ||
               i == 2 && @portrait_loaded[ 1 ] != null
              return # 1つ前のフェーズが終わっていなければ開始しない

            if i == 2
              _diffuse_num = @PORTRAIT_MAX -
                             Math.floor( @PORTRAIT_MAX * 1 / 3 ) * 2
            else
              _diffuse_num = Math.floor( @PORTRAIT_MAX * 1 / 3 )

            @portrait_loaded[ i ] = null # null は、そのフェーズが終了したことを表す
            @$age_num.text i

            switch i
              when 0
                @$episode.text "初めて泣いた。"
              when 1
                @$episode.text "夢を見た。"
              when 2
                @$episode.text "笑った。"
                ticker.clear "TIMER_FROM_START"

            @$result.css
              height: @$result.find( ".info" ).height() + @RESULT_PADDING_HEIGHT
              opacity: 1

            @$result.find( ".info" ).velocity opacity: 1, DUR * 4

            do ( i )=>
              setTimeout =>
                @diffusePortrait _diffuse_num
                @$result.find( ".info" ).velocity opacity: 0
                ,
                  duration: DUR * 4
                  delay: DUR * 2
              , DUR * 6

              if i == 2 # イントロ終了。本編への繋ぎ演出を行う。
                setTimeout =>
                  @$result.velocity
                    backgroundColorAlpha: 0
                    borderColorAlpha: 0
                  , DUR

                  @$result.find( ".logo" ).velocity
                    width: 580
                    height: 300
                  ,
                    duration: DUR * 2
                    delay: DUR * 2
                    complete: =>
                      @$result.find( ".logo" ).velocity opacity: 0
                      ,
                        duration: DUR * 2
                        delay: DUR * 6
                        complete: =>
                          @$result_container.velocity opacity: [ 0, 1 ]
                          , DUR * 2, =>
                            @$result_container.hide()
                            @$result.removeAttr "style"
                            @$result.find( ".info" ).removeAttr "style"
                            @$result.find( ".logo" ).removeAttr "style"
                            @$result.find( ".name_particle" ).show()
                            @dispatch "FIN_INTRO"
                          @showSearchBar()
                , DUR * 18

  showResult: ( age, id )->
    _info = @origin_episode[ age ][ id ]

    @$result_container.removeClass( "withoutPortrait" ).addClass "is_animating"

    @$name.text _info.name
    @$episode.html _info.episode
    @$age_num.text ""
    @$link.find( "a" ).attr
      href: "#{ @WIKI_LINK_ORIGIN }#{ encodeURIComponent( _info.name ) }"

    # set layout
    if _info.name.length > 11
      @$name.css fontSize: 28
    else if _info.name.length > 10
      @$name.css fontSize: 32
    else
      @$name.css fontSize: 36

    @$result.css
      height: @$result.find( ".info" ).height() + @RESULT_PADDING_HEIGHT
      opacity: 1

    @$result.find( ".info" ).css opacity: 1
    @$result.find( ".portrait" ).show()

    if _info.portrait.length > 0
      _img = new Image()
      _img.src = _info.portrait
      _img.style.opacity = 1
      @$portrait.empty()
      @$portrait.append _img
    else
      @$result_container.addClass "withoutPortrait"

    @$result_container.show().velocity opacity: [ 1, 0 ], DUR, =>
      if _info.birth != "不明"
        @dropPin parseInt( age ) + parseInt( _info.birth )
      else
        @$result_container.removeClass "is_animating"

      @roulette_sound.play()
      ticker.listen "AGE_COUNTUP", ( t )=>
        _age = Math.floor( t / 30 )
        if _age > age
          ticker.clear "AGE_COUNTUP"
          @roulette_sound.pause()
          @roulette_sound.currentTime = 0

          setTimeout => # Yahoo! 仕様 FINALE表示
            return if skip
            @$result.velocity
              width: 720
              height: 450
            , DUR, =>
              @$result.find( ".info, .portrait, .logo" ).velocity
                opacity: 0
              , DUR, =>
                @$result.find( ".info, .portrait, .logo" ).hide()
                @$result.find( ".yahoo-msg" ).show().velocity opacity: 1, =>
                  setTimeout =>
                    @$result.find( ".yahoo-msg-2" ).addClass "underline"
                  , DUR * 2
                , DUR
          , DUR * 10
        else
          @$age_num.text _age

    @$result.css
      height: @$result.find( ".info" ).height() + @RESULT_PADDING_HEIGHT

  closeResult: ->
    return # Yahoo!仕様, 1度きりしか見られないようにする？
    @close_sound.currentTime = 0
    @close_sound.play()

    @$pin.velocity opacity: [ 0, 1 ], DUR

    @$result_container.velocity opacity: [ 0, 1 ], DUR, =>
      @$result_container.hide()

  setWinWidth: ( win_width )-> @win_width = win_width

  showSearchBar: ->
    return if parseInt( @$search_container.css "opacity" ) != 0

    @$search_container.velocity
      translateY: [ 0, -20 ]
      opacity: [ 1, 0 ]
    , DUR * 4

  exec: ->
    ###########################
    # EVENT LISTENER
    ###########################

    @$search.one "click", =>
      @$search.attr type: "number"
      .val( "" )
      .addClass "on"

    @$result_container.on "click", ( e )=>
      return if @$result_container.hasClass "is_animating"
      @closeResult() if $( e.target ).hasClass "close"

    @$win.on "keydown", ( e )=>
      if @$result_container.hasClass "is_animating" ||
         @$result_container.css( "display" ) == "none"
        return

      @closeResult() if e.keyCode == @ESCAPE_KEYCODE

    @$enter.on "click", => @search @$search.val()

    $( window ).on "keydown", ( e )=>
      @search @$search.val() if e.keyCode == ENTER_KEY

getInstance = ->
  if !instance
    instance = new Search()
  return instance

module.exports = getInstance
