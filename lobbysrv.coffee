WebSocketServer = require('ws').Server
websocket       = require 'websocket-stream'
duplexEmitter   = require 'duplex-emitter'
program         = require 'commander'

PeerServer = require('peer').PeerServer

# the peerjs server used to establish connections between peers
server = new PeerServer { port: 9000 }

games = []

###
# TODO: This might be valuable for lobbies that stay open for a while
waiting to start. not sure if it's needed yet though.
setInterval (->
  for game in games
    gameBcast game, 'noop'
), 3000
###

program
.option('-p, --port [port]', 'port to run on [8080]', 8080)
.parse(process.argv)

wss = new WebSocketServer(port: program.port)
console.log "started lobby server on port #{program.port}"

wss.on 'connection', (ws) ->
  findGame = (peerID) ->
    for game in games
      for player in game.players
        if player.peerID is peerID
          return game
    false

  # send a messsage to all members of a game
  gameBcast = (game, label, msg) ->
    for p in game.players
      p.emitter.emit label, msg

  gamePlayerNames = (game) ->
    names = []
    for p in game.players
      names.push p.name
    names

  leaveLobby = (peerID) ->
    game = findGame peerID
    if game
      idx = 0
      for player in game.players
        if player.peerID is peerID
          game.players.splice idx, 1
          gameBcast game, 'lobby_leave', JSON.stringify(gamePlayerNames(game))
          # remove empty games
          if game.players.length is 0
            removeGame game
          return
        idx++

  # garbage collect any disconnected players
  removeDisconnectedPeers = ->
    for game in games
      for player in game.players
        closed = !player? or player.emitter.write._stream.ws.readyState is 3
        if closed
          leaveLobby player.peerID


  startGame = (game) ->
    g = 
      host : game.host
      players : []
    for p in game.players
      g.players.push { name: p.name, peerID: p.peerID }

    gameBcast game, 'lobby_start', g
    removeGame game

  removeGame = (game) ->
    console.log 'removing lobby', game.host
    idx = 0
    for g in games
      if g.host is game.host
        games.splice idx, 1
        return
      idx++


  stream = websocket(ws)
  emitter = duplexEmitter(stream)
  peerID = undefined
  stream.once 'end', =>
    removeDisconnectedPeers()
  stream.once 'error', =>
    removeDisconnectedPeers()
  emitter.on 'connected', =>
    leaveLobby(peerID)


  emitter.on 'create', (peerID, name, maxPlayers) ->
    # TODO: clamp max players to some upper limits
    player =
      peerID   : peerID
      name     : name
      emitter : emitter
    game =
      maxPlayers : maxPlayers
      host       : peerID
      players    : [ player ]
    emitter.emit 'lobby_join', name, gamePlayerNames(game)
    games.push game


  emitter.on 'join', (peerID, name) ->
    for game in games
      player =
        peerID  : peerID
        name    : name
        emitter : emitter
      game.players.push player
      if game.players.length is game.maxPlayers
        startGame game
      else
        for p in game.players
          p.emitter.emit 'lobby_join', name, gamePlayerNames(game)
      return


  # host only
  emitter.on 'start', (peerID) ->
    console.log 'starting game', peerID
    for game in games
      if game.host is peerID
        startGame game
        return


  emitter.on 'leave', (peerID) ->
    console.log 'leeavinnnng', peerID
    # TODO: handle host leaving. Assign new host id?
    leaveLobby peerID
