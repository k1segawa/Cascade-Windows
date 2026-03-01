# Window Cascade Tool for AutoHotkey v2

A simple and customizable window cascade script for Windows.

This tool arranges open windows diagonally using configurable offset values.  
You can set different offset values for each application.

---

## ✨ Features

- Cascade all open windows with a single hotkey
- Set custom offset (width/height) per application
- Uses default value (24x24) when not registered
- Automatically creates INI configuration file
- Windows 11 compatible
- Skips:
  - Minimized windows
  - Fullscreen windows
  - Tool windows
  - Child windows
  - Cloaked (UWP hidden) windows

---

## ⌨ Hotkeys

| Key | Function |
|------|----------|
| F9 | Cascade all windows |
| F10 | Set offset for active window |

---

## ⚙ Configuration File

The script automatically creates:

    WindowCascade.ini

Location:  
Same folder as the script.

### Unregistered Section

If no offset is registered for an application, the script uses:

    [Unregistered]
    Width=24
    Height=24

You can modify this manually if needed.

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
4. Press **F9** to cascade them
5. Press **F10** on any window to set custom offset

After saving offset values, press F9 again to apply new settings.

---

## 📌 Notes

- Windows Terminal and modern Windows 11 apps are supported.
- The script filters special internal windows to prevent layout errors.
- Offset is cumulative (diagonal stacking).

---

## 📄 License

MIT License

---

# 日本語説明

AutoHotkey v2 用のウインドウカスケードツールです。

開いているウインドウを、指定したずらし量で斜めに再配置します。  
アプリごとにずらす幅と高さを設定できます。

---

## ✨ 特徴

- ホットキー1つで再配置
- アプリごとのずらし量設定可能
- 未登録時はデフォルト値 (24x24) を使用
- INIファイル自動生成
- Windows 11対応
- 以下を自動除外:
  - 最小化ウインドウ
  - フルスクリーン
  - ツールウインドウ
  - 子ウインドウ
  - Cloakedウインドウ（UWP内部）

---

## ⌨ ホットキー

| キー | 動作 |
|------|------|
| F9 | 全ウインドウ再配置 |
| F10 | アクティブウインドウのずらし量設定 |

---

## ⚙ 設定ファイル

スクリプトと同じフォルダに

    WindowCascade.ini

が自動生成されます。

未登録アプリは以下の値が使われます。

    [Unregistered]
    Width=24
    Height=24

---

## 🚀 使用方法

1. AutoHotkey v2 をインストール
2. スクリプトを実行
3. 複数ウインドウを開く
4. F9キーでカスケード配置
5. F10キーでずらし量を設定

保存後、再度F9で新しい設定が反映されます。

---

## 📄 ライセンス

MIT License
