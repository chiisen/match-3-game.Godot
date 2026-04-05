# 🤖 Godot MCP 使用指南

本專案已設定 `godot-mcp`，可讓 AI 代理直接與 Godot 編輯器互動。

## 📦 已安裝項目

- ✅ `@coding-solo/godot-mcp` (全域安裝)
- ✅ Godot 路徑：`D:\Godot\4.2.2\Godot_v4.2.2-stable_win64.exe`

## 🔧 設定方式

### 在支援的 AI 工具中使用

將以下設定加入你的 AI 工具（Claude Desktop / Cursor / Cline）的 MCP 設定檔：

```json
{
  "mcpServers": {
    "godot": {
      "command": "npx",
      "args": ["-y", "@coding-solo/godot-mcp"],
      "env": {
        "GODOT_PATH": "D:\\Godot\\4.2.2\\Godot_v4.2.2-stable_win64.exe"
      }
    }
  }
}
```

> 💡 完整設定檔已存在於 `mcp-settings.json`

## 🛠️ 可用的 MCP 工具

| 工具名稱 | 功能說明 | Godot 4.2 相容 |
|---------|---------|---------------|
| `launch_editor` | 啟動 Godot 編輯器 | ✅ |
| `run_project` | 運行遊戲專案 | ✅ |
| `get_debug_output` | 取得遊戲運行日誌 | ✅ |
| `stop_project` | 停止運行的遊戲 | ✅ |
| `get_godot_version` | 取得 Godot 版本 | ✅ |
| `list_projects` | 列出目錄中的專案 | ✅ |
| `get_project_info` | 取得專案詳細資訊 | ✅ |
| `create_scene` | 建立新場景 | ✅ |
| `add_node` | 新增節點到場景 | ✅ |
| `load_sprite` | 載入貼圖到節點 | ✅ |
| `export_mesh_library` | 匯出網格庫 | ✅ |
| `save_scene` | 儲存場景 | ✅ |
| `get_uid` | 取得資源 UID | ⚠️ 需 4.4+ |
| `update_project_uids` | 更新專案 UID | ⚠️ 需 4.4+ |

## 💡 實際使用範例

### 1. 啟動編輯器
```
AI 會執行：launch_editor
→ 自動開啟 Godot 編輯器並載入本專案
```

### 2. 運行遊戲並除錯
```
AI 會執行：
1. run_project → 啟動遊戲
2. get_debug_output → 讀取控制台輸出
3. stop_project → 關閉遊戲
→ AI 可以分析日誌找出 Bug
```

### 3. 建立新場景
```
AI 會執行：
1. create_scene → 建立 res://scenes/new_level.tscn
2. add_node → 新增 Node2D、Sprite2D 等
3. save_scene → 儲存場景
```

## 🎯 適合的使用場景

- ✅ **AI 自動除錯**：運行遊戲 → 抓日誌 → 分析錯誤
- ✅ **快速原型**：AI 自動建立場景與節點
- ✅ **批次操作**：大量修改場景結構
- ✅ **自動化測試**：AI 自動運行並檢查輸出

## ⚠️ 注意事項

1. **Godot 版本**：你是 4.2，UID 相關功能無法使用（但不影響核心功能）
2. **編輯器鎖定**：MCP 操作時請確保 Godot 編輯器已關閉，避免衝突
3. **權限問題**：Windows 可能需要管理員權限才能控制程序

## 🚀 快速測試

在支援 MCP 的 AI 工具中，試著要求：

> 「幫我啟動 Godot 編輯器並載入本專案」
> 「運行這個 Match-3 遊戲並告訴我日誌裡有什麼」
> 「建立一個新的測試場景到 scenes/test.tscn」

AI 就會自動呼叫對應的 MCP 工具！
