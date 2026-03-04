# Window Cascade Tool for AutoHotkey v2

A customizable and intelligent window cascade tool for Windows.

A window arranging feature similar to the one available in Windows 10.

This script arranges open windows diagonally using configurable offset values.
You can define different offsets per application and optionally match all window sizes to the front window.

---

## ✨ Features

- Cascade all open windows with a single hotkey
- Set custom offset (width / height) per application
- Default offset (24x24) for unregistered applications
- Update settings instantly without closing the GUI
- Optional: Match all windows to the front window size
- Force redraw after update (prevents visual glitches)
- Automatically creates INI configuration file
- Windows 10 / 11 compatible
- Automatically skips:
  - Minimized windows
  - Fullscreen windows
  - Tool windows
  - Child windows
  - Cloaked (UWP hidden) windows
  - The configuration GUI itself

---

## ⌨ Hotkeys

| Key | Function |
|------|----------|
| F9 | Cascade all windows |
| F10 | Open offset configuration GUI |

---

## ⚙ Configuration File

The script automatically creates:

cascade_offsets.ini

Location:
Same folder as the script.

### Default (Unregistered) Section

If no offset is registered for an application, the script uses:

[Unregistered]
Width=24
Height=24

You may edit this manually if needed.

Each application is stored as its executable name:

[notepad.exe]
Width=40
Height=40

---

## 🛠 Requirements

- Windows 10 / Windows 11
- AutoHotkey v2.0+

Download AutoHotkey:
https://www.autohotkey.com/

---

## 🚀 How to Use

1. Install AutoHotkey v2
2. Run the script
3. Open multiple windows
4. Press F9 to cascade them
5. Press F10 to open the settings GUI
6. Select an application and set offset values
7. Click Update to apply instantly
   or click Save to store and close

After saving, press F9 again anytime to apply.

---

## 🧠 How It Works

- Windows are stacked diagonally using cumulative offset values.
- Offset is applied per executable name.
- If "Match front window size" is enabled:
  - All windows are resized to the front window (excluding the GUI).
- Update triggers forced redraw to prevent rendering artifacts.

---

## 📌 Notes

- Modern Windows 11 apps are supported.
- The GUI window is excluded from cascade processing.
- Offset stacking is cumulative (diagonal layout).
- Designed to avoid layout conflicts with special system windows.
- Blog:https://k1segawa.exblog.jp/245101621/

---

## 📄 License

MIT License

---

# 日本語説明

AutoHotkey v2 で作成されたウインドウカスケードツールです。
Windows 10にあったウインドウを整列させる機能です。

開いているウインドウを、指定したずらし量で斜めに再配置します。
アプリごとにずらす幅と高さを設定でき、
最前面ウインドウのサイズに揃えることも可能です。

---

## ✨ 特徴

- ホットキー1つで再配置
- アプリごとのずらし量設定可能
- 未登録時はデフォルト値 (24x24) を使用
- 更新ボタンで閉じずに即反映
- 最前面ウインドウサイズに揃えるオプション
- 更新時に強制再描画
- INIファイル自動生成
- Windows 10 / 11対応
- 以下を自動除外:
  - 最小化ウインドウ
  - フルスクリーン
  - ツールウインドウ
  - 子ウインドウ
  - Cloakedウインドウ（UWP内部）
  - 設定GUI自身

---

## ⌨ ホットキー

| キー | 動作 |
|------|------|
| F9 | 全ウインドウ再配置 |
| F10 | 設定GUIを開く |

---

## ⚙ 設定ファイル

スクリプトと同じフォルダに

cascade_offsets.ini

が自動生成されます。

未登録アプリは以下の値が使用されます。

[Unregistered]
Width=24
Height=24

アプリごとに以下のように保存されます。

[notepad.exe]
Width=40
Height=40

---

## 🚀 使用方法

1. AutoHotkey v2 をインストール
2. スクリプトを実行
3. 複数ウインドウを開く
4. F9キーでカスケード配置
5. F10キーで設定GUIを開く
6. ずらし量を設定
7. 更新で即反映、保存で保存して閉じる

---

## 📄 ライセンス

MIT License

---

## 📌 Blog

[ChatGPT] ウインドウのカスケード配置 (左上から斜め下へ重なるように) - タイル型や分割でなく [AutoHotKey v2] (3/1) : 体重と今日食べたもの

https://k1segawa.exblog.jp/245101621/
