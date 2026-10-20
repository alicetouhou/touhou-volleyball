extends RefCounted
class_name AcknowledgementTracker


## Recent ticks that have been acknowledged by the remote peer.
var remote_acknowledged_ticks: Array[int] = []
## The most recent acknowledged tick by the remote peer.
var remote_latest_acknowledgement := 0

## How many ticks from the [member latest_acknowledgment] are cached in [member remote_acknowledged_ticks].
## Ticks older than this are dropped.[br][br]
## For example, if [member latest_acknowledgment] was 100, and [member acknowledgement_cache_length]
## was 16, ticks before tick 84 would be dropped from [member remote_acknowledged_ticks].
var acknowledgement_cache_length: int = 16

## The latest ticks recieved by the client.
var recieved_ticks: Array[int] = []

## Check if a tick has been acknowledged. If the tick is not cached
## (i.e it is at least [member acknowledgement_cache_length] ticks older than
## [member latest_acknowledgment]), assumes the tick was acknowledged.
func get_tick_acknowledged(tick: int) -> bool:
	if tick < 0:
		return true
	
	if tick < (remote_latest_acknowledgement - acknowledgement_cache_length):
		return true

	if tick in remote_acknowledged_ticks:
		return true

	return false

## Acknowledge a new tick and it's bitmap of previously acknowledged ticks.
func new_acknowledgement(acknowledge_from: int, acknowledgement_bitmap: int) -> void:
	remote_latest_acknowledgement = maxi(acknowledge_from, remote_latest_acknowledgement)
	for bit in 8:
		if acknowledgement_bitmap & (1 << bit) and (acknowledge_from - 1 - bit) not in remote_acknowledged_ticks:
			remote_acknowledged_ticks.push_back(acknowledge_from - 1 - bit)
	
	remote_acknowledged_ticks = remote_acknowledged_ticks.filter(
		func(tick): return tick >= (remote_latest_acknowledgement - acknowledgement_cache_length)
	)

func get_unacknowledged_ticks(current_tick: int) -> Array[int]:
	var unacknowledged: Array[int] = []
	for tick in range(current_tick - 8, current_tick + 1):
		if not get_tick_acknowledged(tick):
			unacknowledged.push_back(tick)
	return unacknowledged

## Mark an InputFrame as having being recieved
func tick_recieved(tick: int) -> void:
	recieved_ticks.push_back(tick)

## Get the latest tick we have recieved, and which ticks before that we have recieved.
func get_acknowledgement() -> PackedByteArray:
	if recieved_ticks.is_empty():
		return [0, 0]
	var newest_tick: int = recieved_ticks.max()
	recieved_ticks = recieved_ticks.filter(
		func(tick): return tick > newest_tick - 9
	)
	var bitmap := 0
	for tick in recieved_ticks:
		var bit_offset := newest_tick - tick - 1
		bitmap |= 1 << bit_offset
	return [newest_tick, bitmap]
