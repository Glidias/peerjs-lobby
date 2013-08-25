var Lobby = require('./index.js').Lobby;

var l = new Lobby();
var chatPeers = null;

l.on('start', function(peers){
	console.log('game started', peers);
	chatPeers = peers;
	showChat();
	chatPeers.on('message', function(peerID, msg){
		var elem = document.getElementById('chat-data');
		elem.value += (chatPeers.players[peerID].name + ': ' + msg + '\n'); 
	});
});

window.createGame = function(){
	showLobby();
	var playerName = document.getElementById('peer-name').value;
	var maxPlayers = 3;
	l.create(playerName, maxPlayers, function(evt, name, players){	
		console.log('membership', evt, name, players);
		var html = '';
		for(var i=0; i < players.length;i++) {
			html += ('<li>' + players[i] + '</li>');
		}
		document.getElementById('lobby-ppl').innerHTML = html;
		}
	);
}

window.joinGame = function(){
	var playerName = document.getElementById('peer-name').value;
	l.join(playerName, function(evt, name, players){
		console.log('membership', evt, name, players);
		var html = '';
		for(var i=0; i < players.length;i++) {
			html += ('<li>' + players[i] + '</li>');
		}
		document.getElementById('lobby-ppl').innerHTML = html;
	}
	);
	showLobby();
}

window.sendChat = function() {
	var msg = document.getElementById('chat-input').value;
	chatPeers.bcast(msg);
	document.getElementById('chat-data').value += ('me: ' + msg + '\n'); 
}

window.startGame = function() {
	l.start();
}

window.showLobby = function() {
	// show the lobby
	document.getElementById('menu').style.display = 'none';
	document.getElementById('lobby').style.display = '';
}

window.showChat = function() {
	// show the lobby
	document.getElementById('lobby').style.display = 'none';
	document.getElementById('chat').style.display = '';
}
