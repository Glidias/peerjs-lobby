websocket     = require 'websocket-stream'
duplexEmitter = require 'duplex-emitter'
{EventEmitter}  = require 'events'

###
TODO ?
  shared game clock
  dead reckoning/extrapolation
  interpolation
  client side prediction
###

class Lobby extends EventEmitter
  constructor: ->
    # create an id to communicate with the peerjs service
    @peerID = ~~(Math.random() * 10000) + '' + ~~(Math.random() * 10000)
    @emitter = null
    @socket = null

  # create a new lobby. Only valid in a lobby context
  create: (name, maxPlayers=5, @memberCallback) ->
    @emitter or= @_connect()
    @emitter.emit 'create', @peerID, name, maxPlayers

  # inform the lobby server that we're looking for a connection
  join: (name, @memberCallback) ->
    @emitter or= @_connect()
    @emitter.emit 'join', @peerID, name

  # start an existing game. Only valid if in a lobby and the host
  start: ->
    if !@emitter
      throw new Error('never called create or join');
    @emitter.emit 'start', @peerID

  leave: ->
    @emitter.emit 'leave', @peerID

  _connect: ->
    @socket = websocket('ws://localhost:8080')
    emitter = duplexEmitter(@socket)

    emitter.on 'lobby_leave', (players) =>
      players = JSON.parse players
      @memberCallback 'leave', null, players

    # the user created a game or joined one
    emitter.on 'lobby_join', (name, players) =>
      @memberCallback 'join', name, players

    emitter.on 'lobby_start', (gameInfo) =>
      # close the connection to the lobby server
      emitter.emit 'connected'
      @socket.ws.close()
      @emitter = null
      @socket = null

      # create a new PeerList object, build the socket connections. When 
      # completed, emit start event
      p = new PeerList @peerID, gameInfo, =>
        @emit 'start', p
    emitter


class PeerList extends EventEmitter
  # TODO: support options passed to constructor (peerjs server)
  constructor: (@peerID, gameInfo, callback) ->
    @players = {}
    @peer = new Peer(@peerID,
      host: 'localhost'
      port: 9000
    )
    @peer.on 'connection', (conn) =>
      console.log 'received connection from a peer', conn
      conn.on 'data', (msg) =>
        @_recv conn.peer, msg

      conn.on 'error', @_removePeer
      conn.on 'close', @_removePeer
      @players[conn.peer] = 
        name: @_findPlayerName(conn.peer, gameInfo)
        conn: conn

    @peer.on 'error', (e) ->
      console.log 'peerjs error evt', e
    @peer.on 'close', () ->
      console.log 'peerjs close evt'

    # connect socket to all game players
    for p in gameInfo.players
      # dont connect a socket to your own player
      # only connect to a peer with a lower peerID (ensures no redundant socket connections)
      if p.peerID isnt @peerID and @peerID < p.peerID
        console.log 'connecting to peer', p.peerID
        @_createPeerConnection p.peerID, p.name
    # wait a little while to connect
    setTimeout callback, 3000

  bcast: (msg) ->
    for peerID, player of @players
      if peerID isnt @peerID
        console.log 'sending to', peerID, msg
        player.conn.send msg

  leave: ->
    @bcast 'leave'
    # TODO: consider creating and acknowledgement as a form of callback
    # peerjs lacks a send callback so just wait a while for the message to deliver
    setTimeout(
      () =>
        for peerID, player of @players
          if peerID isnt @peerID
            player.conn.close()
      4000
    )

  _createPeerConnection: (peerID, name) ->
    conn = @peer.connect peerID
    conn.on 'open', =>
      console.log 'successfully connected to peer'
      @players[peerID] = 
        name: name
        conn: conn

    conn.on 'data', (msg) =>
      @_recv peerID, msg

    conn.on 'error', (er) =>
      console.log 'peer connection error', er
      @_removePeer()

    conn.on 'close', =>
      console.log 'peer close'
      @_removePeer()

  _findPlayerName: (peerID, gameInfo) ->
    for player in gameInfo.players
        if player.peerID is peerID
          return player.name
    null

  _recv: (peerID, msg) =>
    @emit 'message', peerID, msg

  _removePeer: ->
    @emit 'leave', @peer

  
module.exports.PeerList = PeerList
module.exports.Lobby    = Lobby
