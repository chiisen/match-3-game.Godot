extends Node
## 全域日誌系統 - 提供統一的日誌記錄與防衛性檢查
## 日誌會同時輸出到控制台和檔案，方便 AI Agent 除錯

enum LogLevel { DEBUG, INFO, WARN, ERROR, FATAL }

var log_file: FileAccess = null
var log_level: LogLevel = LogLevel.DEBUG
var max_log_lines: int = 500  # 記憶體中保留的最大行數
var log_buffer: PackedStringArray = []

func _ready() -> void:
	_open_log_file()
	_info("Logger", "日誌系統初始化完成")

func _exit_tree() -> void:
	_close_log_file()

# ============================================================
# 公開 API - 供其他腳本呼叫
# ============================================================

func debug(source: String, msg: String) -> void:
	_log(LogLevel.DEBUG, source, msg)

func info(source: String, msg: String) -> void:
	_log(LogLevel.INFO, source, msg)

func warn(source: String, msg: String) -> void:
	_log(LogLevel.WARN, source, msg)

func error(source: String, msg: String, extra: Dictionary = {}) -> void:
	var full_msg := msg
	if not extra.is_empty():
		var details := []
		for key in extra:
			details.append(str(key) + "=" + str(extra[key]))
		full_msg += " [" + ", ".join(details) + "]"
	_log(LogLevel.ERROR, source, full_msg)

func fatal(source: String, msg: String, extra: Dictionary = {}) -> void:
	var full_msg := "💀 FATAL: " + msg
	if not extra.is_empty():
		var details := []
		for key in extra:
			details.append(str(key) + "=" + str(extra[key]))
		full_msg += " [" + ", ".join(details) + "]"
	_log(LogLevel.FATAL, source, full_msg)

# 防衛性檢查輔助函式
func assert_not_null(source: String, value, name: String, context: String = "") -> bool:
	if value == null:
		error(source, "NULL_CHECK_FAILED: " + name + " is null" + (" | " + context if context else ""))
		return false
	return true

func assert_in_range(source: String, value: int, min_val: int, max_val: int, name: String = "") -> bool:
	if value < min_val or value > max_val:
		error(source, "RANGE_CHECK_FAILED: " + name + "=" + str(value) + " out of [" + str(min_val) + "," + str(max_val) + "]")
		return false
	return true

func assert_state(source: String, current_state, expected_states: Array, context: String = "") -> bool:
	if not current_state in expected_states:
		error(source, "STATE_CHECK_FAILED: current=" + str(current_state) + " expected=" + str(expected_states) + (" | " + context if context else ""))
		return false
	return true

# 快速記錄遊戲事件
func game_event(event_name: String, details: Dictionary = {}) -> void:
	var msg := "🎮 EVENT: " + event_name
	if not details.is_empty():
		var parts := []
		for key in details:
			parts.append(str(key) + "=" + str(details[key]))
		msg += " | " + ", ".join(parts)
	_info("Game", msg)

# ============================================================
# 內部實作
# ============================================================

func _open_log_file() -> void:
	var path := "user://game_runtime.log"
	log_file = FileAccess.open(path, FileAccess.WRITE)
	if log_file:
		log_file.store_line("=== 波妞消消樂 遊戲日誌 ===")
		log_file.store_line("啟動時間: " + Time.get_datetime_string_from_system())
		log_file.store_line("===========================")
	else:
		printerr("[Logger] 無法建立日誌檔: " + path)

func _close_log_file() -> void:
	if log_file:
		log_file.store_line("=== 日誌結束: " + Time.get_datetime_string_from_system() + " ===")
		log_file.close()
		log_file = null

func _log(level: LogLevel, source: String, msg: String) -> void:
	if level < log_level:
		return
	
	var timestamp := Time.get_time_string_from_system()
	var prefix := _get_level_prefix(level)
	var line := "[" + timestamp + "] " + prefix + " [" + source + "] " + msg
	
	# 輸出到控制台
	if level >= LogLevel.WARN:
		printerr(line)
	else:
		print(line)
	
	# 寫入檔案
	if log_file:
		log_file.store_line(line)
		log_file.flush()
	
	# 加入記憶體緩衝
	log_buffer.append(line)
	if log_buffer.size() > max_log_lines:
		log_buffer.remove_at(0)

func _get_level_prefix(level: LogLevel) -> String:
	match level:
		LogLevel.DEBUG: return "🔍"
		LogLevel.INFO:  return "ℹ️"
		LogLevel.WARN:  return "⚠️"
		LogLevel.ERROR: return "❌"
		LogLevel.FATAL: return "💀"
	return "?"

func _info(source: String, msg: String) -> void:
	_log(LogLevel.INFO, source, msg)
