extends Node

const BOARD_SIZE := 7
const GEM_TYPES := 6

const SWAP_DURATION := 0.2
const REMOVE_DURATION := 0.3
const FALL_DURATION := 0.4
const HINT_DELAY := 5.0
const TIMED_MODE_DURATION := 60

const SCORE_3_MATCH := 30
const SCORE_4_MATCH := 60
const SCORE_5_MATCH := 100
const CHAIN_MULTIPLIER := 1.5

const HIGH_SCORE_KEY := "match3_highScore"
const MUTE_KEY := "match3_mute"

enum GameState {
	IDLE,
	SELECTED,
	SWAPPING,
	REMOVING,
	FALLING,
	GAME_OVER
}

enum GameMode {
	CLASSIC,
	TIMED
}

const GEM_COLORS := {
	1: Color("#ff4d6a"),
	2: Color("#00c9ff"),
	3: Color("#50e85a"),
	4: Color("#ffcc00"),
	5: Color("#cc66ff"),
	6: Color("#ff8c1a"),
}

const GEM_TEXTURES := {
	1: "res://assets/images/gem1.png",
	2: "res://assets/images/gem2.png",
	3: "res://assets/images/gem3.png",
	4: "res://assets/images/gem4.png",
	5: "res://assets/images/gem5.png",
	6: "res://assets/images/gem6.png",
}
