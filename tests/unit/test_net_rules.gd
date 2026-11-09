extends GutTest
## Score, interpolation, discovery messages and input replication.

const HOST := 1
const GUEST := 2

var score: DeathmatchScore


func before_each() -> void:
	score = DeathmatchScore.new([HOST, GUEST], 10, 300.0)


func test_deathmatch_rules_match_design() -> void:
	assert_eq(int(Tuning.section("deathmatch")["kill_limit"]), 10)
	assert_eq(float(Tuning.section("deathmatch")["time_limit"]), 300.0)
	assert_eq(int(Tuning.section("net")["lan_port"]), 7777)
	assert_eq(int(Tuning.section("net")["discovery_port"]), 7778)
	assert_eq(float(Tuning.section("net")["join_timeout"]), 10.0)
	assert_eq(float(Tuning.section("net")["state_interval"]), 0.05)


func test_tenth_kill_wins() -> void:
	for i: int in range(9):
		score.record_death(GUEST, HOST)
	assert_false(score.is_over())
	score.record_death(GUEST, HOST)
	assert_true(score.is_over())
	assert_eq(score.winner(), HOST)


func test_most_kills_wins_when_time_runs_out() -> void:
	score.record_death(HOST, GUEST)
	score.record_death(HOST, GUEST)
	score.record_death(GUEST, HOST)
	score.update(301.0)
	assert_eq(score.winner(), GUEST)


func test_tie_at_time_up_is_a_draw() -> void:
	score.record_death(GUEST, HOST)
	score.record_death(HOST, GUEST)
	score.update(301.0)
	assert_true(score.is_over())
	assert_eq(score.winner(), DeathmatchScore.DRAW)


func test_no_kills_at_time_up_is_a_draw() -> void:
	score.update(301.0)
	assert_eq(score.winner(), DeathmatchScore.DRAW)


func test_killing_yourself_scores_no_kill() -> void:
	score.record_death(HOST, HOST)
	assert_eq(score.kills[HOST], 0)
	assert_eq(score.deaths[HOST], 1)


func test_death_with_no_killer_scores_no_kill() -> void:
	score.record_death(HOST, 0)
	assert_eq(score.deaths[HOST], 1)
	assert_eq(score.kills[GUEST], 0)


func test_result_cannot_change_once_over() -> void:
	for i: int in range(10):
		score.record_death(GUEST, HOST)
	score.record_death(HOST, GUEST)
	assert_eq(score.kills[GUEST], 0)


func test_snapshot_blends_between_samples() -> void:
	var buffer := SnapshotBuffer.new()
	buffer.push(1.0, Vector2(0.0, 0.0))
	buffer.push(2.0, Vector2(100.0, 0.0))
	assert_eq(buffer.sample(1.5), Vector2(50.0, 0.0))


func test_snapshot_before_the_first_uses_the_first() -> void:
	var buffer := SnapshotBuffer.new()
	buffer.push(1.0, Vector2(10.0, 0.0))
	assert_eq(buffer.sample(0.5), Vector2(10.0, 0.0))


func test_snapshot_after_the_last_holds_the_last() -> void:
	var buffer := SnapshotBuffer.new()
	buffer.push(1.0, Vector2(10.0, 0.0))
	buffer.push(2.0, Vector2(20.0, 0.0))
	assert_eq(buffer.sample(5.0), Vector2(20.0, 0.0))


func test_snapshot_buffer_forgets_old_samples() -> void:
	var buffer := SnapshotBuffer.new()
	for i: int in range(SnapshotBuffer.CAPACITY + 5):
		buffer.push(float(i), Vector2(float(i), 0.0))
	assert_eq(buffer.sample(0.0), Vector2(5.0, 0.0))


func test_discovery_message_round_trips() -> void:
	var message: Dictionary = LanDiscovery.decode(LanDiscovery.encode("1.0.3", "Kris", 7777))
	assert_eq(message["game"], LanDiscovery.GAME_ID)
	assert_eq(message["version"], "1.0.3")
	assert_eq(message["name"], "Kris")
	assert_eq(int(message["port"]), 7777)


func test_other_games_are_ignored() -> void:
	var other: PackedByteArray = JSON.stringify({"game": "chess", "version": "1", "name": "a", "port": 1}).to_utf8_buffer()
	assert_true(LanDiscovery.decode(other).is_empty())


func test_garbage_packets_are_ignored() -> void:
	assert_true(LanDiscovery.decode("not json".to_utf8_buffer()).is_empty())
	assert_true(LanDiscovery.decode(PackedByteArray([1, 2, 3])).is_empty())


func test_listener_hears_a_broadcast_on_this_machine() -> void:
	var listener := LanListener.new()
	listener.discovery_port = 47891
	add_child_autofree(listener)
	var broadcaster := LanBroadcaster.new()
	broadcaster.discovery_port = 47891
	broadcaster.game_port = 7777
	broadcaster.destinations = PackedStringArray(["127.0.0.1"])
	add_child_autofree(broadcaster)
	await wait_seconds(0.2, "")
	assert_eq(listener.hosts.size(), 1)
	assert_true(listener.hosts.has("127.0.0.1"))


func test_input_state_carries_every_field() -> void:
	var input := PlayerInput.new()
	input.move = Vector2(1.0, -1.0)
	input.aim = Vector2.UP
	input.fire = true
	input.jet = true
	input.grenade = true
	input.swap = true
	input.melee = true
	input.crouch = true
	var state := NetInputState.new()
	autofree(state)
	state.capture(input)
	var read: PlayerInput = state.poll(Vector2.ZERO)
	assert_eq(read.move, input.move)
	assert_eq(read.aim, input.aim)
	assert_true(read.fire and read.jet and read.grenade and read.swap and read.melee and read.crouch)
	assert_eq(NetInputState.replicated_properties().size(), 8)


func test_local_addresses_skip_loopback() -> void:
	for address: String in LanDiscovery.local_ipv4_addresses():
		assert_false(address.begins_with("127."), address)
		assert_false(address.contains(":"), address)


func test_multiplayer_results_are_counted() -> void:
	ProgressService.use_directory("user://test_saves/net_rules")
	ProgressService.data = ProgressService._fresh_save()
	ProgressService.record_mp_result("win")
	ProgressService.record_mp_result("loss")
	ProgressService.record_mp_result("loss")
	ProgressService.record_mp_result("draw")
	assert_eq(int(ProgressService.data["stats"]["mp_wins"]), 1)
	assert_eq(int(ProgressService.data["stats"]["mp_losses"]), 2)
	ProgressService.use_directory(ProgressService.DEFAULT_DIRECTORY)
	ProgressService.load_save()
