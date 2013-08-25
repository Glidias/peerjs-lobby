# peerjs-lobby

a browserify package that consists of 

a socket server for hosting lobbies, and a library to connect applications via peerjs (Web RTC)


## Installation

```
cd <your project>
npm install peerjs-lobby --save
```


## Example

see demo/ for an example of how to setup a peer to peer chat server.

1 start the peerjs-lobby server:

```sh
coffee lobbysrv.coffee
```

2 open index.html in 2 browser windows

3 type a name in window 1, click create game

4 type a name in window 2, click join game

5 you should now see the players in the lobby 

6 in window 1 click start game (only the game creator can start a game)

7 you should see both windows display a chat window. you can type in either window and see the output broadcast to all chatters

NOTE: the demo sets max players to 3, so as soon as 3 people connect, it will auto start.

## API

There are 2 classes

### Lobby
Provides all of the calls needed to setup a game

#### Methods

##### create(name, maxPlayers=5, callback)
Create a new lobby with `maxPlayers`. Every time someone joins or leaves the lobby, it will fire a callback event of the form `function(evt, name, players)`


##### join(name, callback)
Join an existing lobby. Every time someone joins or leaves the lobby, it will fire a callback just like the create call above.

##### start()
start a new game with all the players currently in the lobby. 

Note: only the host can call this.

Note: if the lobby fills up with `maxPlayers` this will be called automatically

##### leave()
leave the lobby


#### Events

##### start
emitted when a game is started. returns a `PeerList` object which can be used to communicate with all game members. When this event is received all clients should be fully connected to each other in a p2p configuration.


### PeerList
provides a collection of peer streams and helper methods.

#### Methods

##### bcast(message)
sends a string message to all other peers in the game

##### leave()
lets the other peers know that you're leaving, and disconnects

#### Events

##### message
emitted when new messages arrive from other peers. the callback takes the form of `peerID, msg`

##### leave
emitted when another peer leaves the game. the callback takes the form of `peer`.