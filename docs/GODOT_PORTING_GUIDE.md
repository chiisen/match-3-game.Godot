# Match-3 Game Godot 移植指南

## 專案概述

本指南用於將現有的 HTML5 Canvas 三消遊戲移植到 Godot 4.x 引擎，目標平台為 Web/HTML5。

### 原專案資訊

- **專案名稱**：波妞消消樂 (Match-3 Game)
- **原始技術**：Vanilla JavaScript + HTML5 Canvas
- **遊戲類型**：三消益智遊戲
- **主題**：貓咪（波弟）與小女生（波妞）
- **GitHub**：[chiisen/match-3-game](https://github.com/chiisen/match-3-game)

---

## 遊戲功能清單

### 核心玩法

| 功能 | 描述 |
|------|------|
| 棋盤系統 | 7×7 方格棋盤，填充 6 種貓咪主題圖示 |
| 交換機制 | 點擊選取 + 點擊相鄰方塊交換，或滑動 Swipe 交換 |
| 消除判定 | 水平/垂直 3 個以上相同方塊消除 |
| 掉落填充 | 消除後上方方塊下落，頂部隨機生成新方塊 |
| 連鎖反應 | 掉落後自動觸發連鎖消除 |
| 無效交換 | 無法消除時方塊自動回退 |

### 遊戲模式

| 模式 | 描述 |
|------|------|
| 經典模式 | 無時間限制，無可消除組合時結束 |
| 計時模式 | 60 秒限時挑戰最高分 |

### 計分系統

| 消除類型 | 分數 |
|---------|------|
| 3 消 | 30 分 |
| 4 消 | 60 分 |
| 5+ 消 | 100 分 |
| 連鎖加成 | 每次 ×1.5 倍 |

### UI/功能

- 計分板：當前分數、最高分（localStorage）、連鎖數
- 計時器：倒數顯示（計時模式）
- 提示功能：5 秒無操作自動高亮可消除位置
- 重新開始：隨時可重置遊戲
- 音效開關：儲存至 localStorage

---

## 檔案結構對照

### 現有結構

```
match-3-game/
├── index.html              # 主頁面
├── css/style.css           # 樣式
├── js/
│   ├── main.js             # 入口、初始化、UI 事件
│   ├── game.js             # 遊戲邏輯 (Board, Game 類別)
│   ├── renderer.js         # Canvas 渲染
│   ├── input.js            # 輸入處理 (點擊/觸控)
│   ├── score.js            # 計分管理
│   └── audio.js            # Web Audio 音效
├── assets/
│   ├── images/gem1-6.png   # 6 種寶石圖片
│   └── videos/cheer.webm    # 慶祝影片
└── PRD.md                  # 產品需求文檔
```

### Godot 目標結構

```
match3-godot/
├── project.godot           # Godot 專案檔
├── main.tscn              # 主場景
├── main.gd                # 主程式腳本
├── scripts/
│   ├── game.gd            # 遊戲控制器 (Game 類別)
│   ├── board.gd           # 棋盤邏輯 (Board 類別)
│   ├── gem.gd             # 寶石節點
│   ├── input_handler.gd   # 輸入處理
│   ├── score_manager.gd   # 計分管理
│   ├── audio_manager.gd   # 音效管理
│   └── ui_controller.gd   # UI 控制
├── scenes/
│   ├── game.tscn          # 遊戲場景
│   ├── board.tscn         # 棋盤節點
│   ├── gem.tscn           # 寶石預製體
│   ├── ui/
│   │   ├── main_ui.tscn   # 主 UI
│   │   └── game_over.tscn # 遊戲結束畫面
├── resources/
│   ├── themes/            # UI 主題
│   └── fonts/             # 字體
└── assets/                # 圖片/影片資源 (直接沿用)
    ├── images/
    └── videos/
```

---

## 資源清單（直接沿用）

### 圖片資源

| 檔案 | 用途 |
|------|------|
| `assets/images/gem1.png` | 寶石類型 1（紅色） |
| `assets/images/gem2.png` | 寶石類型 2（藍色） |
| `assets/images/gem3.png` | 寶石類型 3（綠色） |
| `assets/images/gem4.png` | 寶石類型 4（金色） |
| `assets/images/gem5.png` | 寶石類型 5（紫色） |
| `assets/images/gem6.png` | 寶石類型 6（橙色） |

### 影片資源

| 檔案 | 用途 |
|------|------|
| `assets/videos/cheer.webm` | 慶祝動畫影片 |

### 其他資源

| 檔案 | 用途 |
|------|------|
| `favicon.png` | 網站 favicon |
| `Match-3.png` | README 展示圖 |

---

## 移植要點

### 1. 核心類別映射

| JavaScript 類別 | Godot 節點/腳本 |
|----------------|-----------------|
| `Board` | `board.gd` (節點) |
| `Game` | `game.gd` (節點) |
| `Renderer` | Godot 2D 渲染引擎直接處理 |
| `InputHandler` | `input_handler.gd` |
| `ScoreManager` | `score_manager.gd` |
| `AudioManager` | `audio_manager.gd` |

### 2. 棋盤實現

- 使用 `Node2D` 作為 Board 根節點
- 使用 `TextureRect` 或自訂 `Node2D` 繪製寶石
- 寶石動畫使用 `Tween` 節點實現

### 3. 渲染方式

- 放棄 Canvas API，改用 Godot 2D 渲染
- 寶石使用 `Sprite2D` 或 `TextureRect`
- 背景使用 `ColorRect` 或 `TextureRect`
- 粒子效果使用 `CPUParticles2D` 或 `GPUParticles2D`

### 4. 輸入處理

- 使用 Godot 的 `_input()` 或 `_gui_input()` 處理點擊
- 觸控支援：Godot 預設支援觸控事件
- Swipe 偵測：計算 touch start/end 座標差

### 5. 音效實現

- 放棄 Web Audio API，改用 Godot 的 `AudioStreamPlayer`
- 背景音樂：使用 `AudioStreamPlayer` 播放 `.ogg` 或 `.wav`
- 音效：使用 `AudioStreamPlayer` 播放短音效
- 可用 `AudioBus` 處理音量控制

### 6. 影片播放

> [!IMPORTANT]
> **Godot 4.x 重要變更**：`VideoPlayer` 已更名為 `VideoStreamPlayer`

- 使用 `VideoStreamPlayer` 節點播放 `cheer.webm`
- 影片分段控制：在 `_process()` 中監聽 `playback_position`

### 7. 資料儲存

- 使用 `FileAccess` 或 `StorageVariables` 取代 `localStorage`
- 最高分儲存鍵名：`match3_highScore`
- 音效設定儲存鍵名：`match3_mute`

---

## 技術細節

### 常數定義

```gdscript
# game.gd 或 constants.gd
const BOARD_SIZE := 7
const GEM_TYPES := 6
const SWAP_DURATION := 0.2
const REMOVE_DURATION := 0.3
const FALL_DURATION := 0.3
const HINT_DELAY := 5.0
const TIMED_MODE_DURATION := 60
```

### 遊戲狀態

```gdscript
enum GameState {
    IDLE,
    SELECTED,
    SWAPPING,
    REMOVING,
    FALLING,
    GAME_OVER
}
```

### 寶石顏色（參考原專案）

```gdscript
const GEM_COLORS := {
    1: Color("#ff4d6a"),  # 紅
    2: Color("#00c9ff"),  # 藍
    3: Color("#50e85a"),  # 綠
    4: Color("#ffcc00"),  # 金
    5: Color("#cc66ff"),  # 紫
    6: Color("#ff8c1a"),  # 橙
}
```

---

## 驗收標準

1. ✅ 7×7 棋盤正確顯示，6 種寶石圖片正確載入
2. ✅ 點擊選取 + 相鄰交換功能正常
3. ✅ 滑動 Swipe 交換功能正常
4. ✅ 3 消以上正確消除並得分
5. ✅ 消除後方塊正確下落填充
6. ✅ 連鎖反應正確觸發並加成計分
7. ✅ 無效交換正確回退
8. ✅ 經典模式正常運作
9. ✅ 計時模式 60 秒倒數正常
10. ✅ 提示功能 5 秒後觸發
11. ✅ 最高分正確儲存與讀取
12. ✅ 音效播放正常
13. ✅ 慶祝影片正確觸發與分段循環
14. ✅ 遊戲結束畫面正確顯示
15. ✅ 重新開始功能正常
16. ✅ 網頁平台 Export 正常運行

---

## 參考資源

- [Godot 4.x Documentation](https://docs.godotengine.org/en/4.x/)
- [Godot 2D Tutorial - Match-3](https://docs.godotengine.org/en/4.x/tutorials/2d/puzzle_square.html)
- [Godot VideoStreamPlayer ](https://docs.godotengine.org/en/4.x/classes/class_VideoStreamPlayer .html)
- [Godot Audio](https://docs.godotengine.org/en/4.x/tutorials/audio/index.html)
- [Godot Export to Web](https://docs.godotengine.org/en/4.x/tutorials/platform/web/index.html)

---

## 備註

- 原始專案使用 ES Modules，原則上邏輯可直接翻譯為 GDScript
- 圖片與影片資源可直接複製到 Godot 專案使用
- UI 佈局需根據 Godot 的 Control 節點重新設計
- 動畫系統使用 Godot 的 Tween 系統更為方便
