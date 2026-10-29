class_name RemoteRace
extends RefCounted
## Future transport boundary. Offline build never creates a fake opponent,
## room code, live score or message delivery.
signal score_received(player_id: String, score: int)
signal quick_message_received(player_id: String, message_id: String)
enum Status { OFFLINE, CONNECTING, LOBBY, COUNTDOWN, PLAYING, FINISHED }
var status: Status = Status.OFFLINE
const QUICK_MESSAGES = ["Bol şans!", "Güzel hamle!", "Tebrikler!"]

func is_available() -> bool:
	return false
