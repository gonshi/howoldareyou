EventDispatcher = require "../util/eventDispatcher"

instance = null

class EpisodeData extends EventDispatcher
  constructor: ->
    super()
    @episode = {}

    @ageExp = /年齢: (.*?),/
    @episodeExp = /一言エピソード: (.*?),/
    @birthExp = /生年: (.*?),/
    @portraitExp = /画像: (.*?)$/
    @END_PHRASE = "以下未記述欄"

    ########################
    # EVENT LISTENER
    ########################

    window.gdata = {}
    window.gdata.io = {}
    window.gdata.io.handleScriptLoaded = ( response )=>
      _length = response.feed.entry.length

      for i in [ 0..._length ]
        response.feed.entry[ i ].content.$t =
          response.feed.entry[ i ].content.$t.replace /\n/g, ""
        break if response.feed.entry[ i ].title.$t == @END_PHRASE
        _age = response.feed.entry[ i ].content.$t.match( @ageExp )[ 1 ]

        _portrait_id =
          response.feed.entry[ i ].content.$t.match( @portraitExp )[ 1 ]

        if _portrait_id != "なし"
          _portrait = "#{ path }img/portrait/#{ _portrait_id }.png"
        else
          _portrait = ""

        @episode[ _age ] = [] if !@episode[ _age ]?

        @episode[ _age ].push
          id: @episode[ _age ].length
          name: response.feed.entry[ i ].title.$t
          episode: response.feed.entry[ i ].content.$t.match( @episodeExp )[ 1 ]
          birth: response.feed.entry[ i ].content.$t.match( @birthExp )[ 1 ]
          portrait: _portrait

      @dispatch "GOT_DATA", this, @episode

  getData: ->
    @src = "https://spreadsheets.google.com/feeds/list" +
           "/1ThmwlEue4zVhhlFMw7BsQd2Acpiv4Z4Uxz-5oYUlkaM" +
           "/od6/public/basic?alt=json-in-script"
    $( "head" ).append( $( "<script>" ).attr src: @src )

getInstance = ->
  if !instance
    instance = new EpisodeData()
  return instance

module.exports = getInstance
