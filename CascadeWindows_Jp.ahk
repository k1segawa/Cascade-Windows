/*
============================================================
AutoHotkey v2 用 ウインドウカスケードツール
============================================================

作者: k1segawa
ライセンス: MIT
バージョン: 1.4

追加:
- 更新ボタン（閉じずに反映・キー変更）
- リサイズ登録ボタン（最前面サイズを保存）
- リサイズオプション追加
- ホットキー変更可能

概要:
開いているウインドウを指定したずらし量で
重ねて(カスケード)配置します。
アプリごとにずらす幅と高さを設定可能です。
オプションで全ウインドウを登録値でリサイズ

初期ホットキー:
F9  - すべてのウインドウを再配置
F10 - 設定GUI表示(✖キャンセル)

特徴:
- アプリごとの個別設定対応
- 未登録時はデフォルト値(24x24)使用
- 最前面ウインドウのサイズを登録・リサイズ可能
- Windows 10 / 11対応
- 除外ウインドウ:
  最小化 / ツール / 子 / フルスクリーン / Cloaked / スナップ /
  設定GUI(アプリ選択・最前面登録からも) / このスクリプトのMsgBox

終了:
タスクトレイ-[H]アイコン右クリック-Exit

設定ファイル:
cascade_offsets.ini（自動生成）

============================================================
*/

#Requires AutoHotkey v2.0

global OffsetConfig := Map()
global ConfigFile := A_ScriptDir "\cascade_offsets.ini"
global DefaultSection := "Unregistered"
global DefaultW := 24
global DefaultH := 24
global Resize := false

global GlobalSizeW := ""
global GlobalSizeH := ""

global ConfigGuiHwnd := 0

; -------------------------------
; Keybind関連
; -------------------------------
global CascadeHotkey := "F9"
global GuiHotkey := "F10"
global RegisteredCascadeHotkey := ""
global RegisteredGuiHotkey := ""

LoadConfig()
RegisterHotkeys()

; ===============================
; 有効ウインドウ取得
; ===============================
GetValidWindows()
{
    global ConfigGuiHwnd

    winList := WinGetList()
    screenW := A_ScreenWidth
    screenH := A_ScreenHeight

    valid := []

    Loop winList.Length
    {
        hwnd := winList[winList.Length - A_Index + 1]  ; 奥→手前

        ; AutoHotKey除外
        if !WinExist("ahk_id " hwnd)
            continue

        ; このスクリプト自身のウインドウ除外
        if WinGetPID("ahk_id " hwnd) = DllCall("GetCurrentProcessId")
            continue

        ; GUI除外
        if hwnd = ConfigGuiHwnd
            continue

        ; 最小化除外
        if WinGetMinMax("ahk_id " hwnd) = -1
            continue

        ; 親を持つウインドウ除外（子ウインドウ除去）
        if DllCall("GetParent", "ptr", hwnd)
            continue

        ; ツールウインドウ除外
        exStyle := DllCall("GetWindowLongPtr", "ptr", hwnd, "int", -20, "ptr")
        if (exStyle & 0x80)  ; WS_EX_TOOLWINDOW
            continue

        ; Cloaked除外（UWP/仮想デスクトップ裏）
        cloaked := 0
        DllCall("dwmapi\DwmGetWindowAttribute"
            , "ptr", hwnd
            , "int", 14  ; DWMWA_CLOAKED
            , "int*", cloaked
            , "int", 4)

        if cloaked
            continue

        WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)

        ; サイズ0除外
        if (w <= 0 || h <= 0)
            continue

        ; フルスクリーン除外
        if (w >= screenW && h >= screenH)
            continue

        valid.Push(hwnd)
    }

    return valid
}

; ===============================
; 最前面ウインドウ取得
; ===============================
GetTopValidWindow()
{
    valid := GetValidWindows()

    if valid.Length = 0
        return 0

    return valid[valid.Length]
}

; ===============================
; カスケード処理
; ===============================
CascadeWindows(*)
{
    global OffsetConfig, DefaultSection, ConfigFile
    global Resize, DefaultW, DefaultH
    global GlobalSizeW, GlobalSizeH

    validWindows := GetValidWindows()

    totalX := 0
    totalY := 0

    for hwnd in validWindows
    {
        exe := WinGetProcessName("ahk_id " hwnd)

        if OffsetConfig.Has(exe)
        {
            ; 登録済みアプリ
            dx := OffsetConfig[exe].w
            dy := OffsetConfig[exe].h
        }
        else
        {
            ; 未登録アプリ → INIのUnregisteredを読み込む
            dx := IniRead(ConfigFile, DefaultSection, "Width", DefaultW)
            dy := IniRead(ConfigFile, DefaultSection, "Height", DefaultH)
        }

        if Resize && GlobalSizeW != "" && GlobalSizeH != ""
            WinMove(totalX, totalY, GlobalSizeW, GlobalSizeH, "ahk_id " hwnd)
        else
            WinMove(totalX, totalY, , , "ahk_id " hwnd)

        totalX += dx
        totalY += dy
    }
}

; ===============================
; 設定GUI
; ===============================
ShowConfigGui(*)
{
    global OffsetConfig, DefaultW, DefaultH, Resize
    global ConfigGuiHwnd
    global CascadeHotkey, GuiHotkey

    MyGui := Gui("+Resize", "設定")

    ConfigGuiHwnd := MyGui.Hwnd

    winList := WinGetList()
    exeSet := Map()

    for hwnd in winList
    {
        if WinGetMinMax("ahk_id " hwnd) != 0
            continue

        exe := WinGetProcessName("ahk_id " hwnd)
        exeSet[exe] := true
    }

    exeArray := []

    for exe, _ in exeSet
        exeArray.Push(exe)

    MyGui.Add("Text", , "アプリを選択:")
    ddl := MyGui.Add("DropDownList", "w300 vAppChoice", exeArray)
    ddl.Value := 0

    MyGui.Add("Text", , "ずらし幅:")
    MyGui.Add("Edit", "w100 vOffsetW", DefaultW)

    MyGui.Add("Text", , "ずらし高さ:")
    MyGui.Add("Edit", "w100 vOffsetH", DefaultH)

    ; -------------------------------
    ; Keybind設定欄を追加
    ; -------------------------------
    MyGui.Add("Text", , "重ねて配置 ホットキー:")
    MyGui.Add("Edit", "w180 vCascadeHotkey", CascadeHotkey)

    MyGui.Add("Text", , "設定呼び出し ホットキー:")
    MyGui.Add("Edit", "w180 vGuiHotkey", GuiHotkey)

    chk := MyGui.Add("Checkbox", "vResize", "リサイズ")
    chk.Value := Resize

    btnSave := MyGui.Add("Button", "Default", "保存")
    btnUpdate := MyGui.Add("Button", "x+10", "更新")
    btnRegister := MyGui.Add("Button", "x+10", "サイズ登録")
    btnHelp := MyGui.Add("Button", "x+10", "ヘルプ")

    ddl.OnEvent("Change", LoadOffsetToGui)
    btnSave.OnEvent("Click", SaveOffset)
    btnUpdate.OnEvent("Click", UpdateOffset)
    btnRegister.OnEvent("Click", RegisterSize)
    MyGui.OnEvent("Close", OnConfigGuiClose)
    btnHelp.OnEvent("Click", OnShowConfigHelp)

    MyGui.Show()
}

OnConfigGuiClose(guiObj)
{
    global ConfigGuiHwnd
    ConfigGuiHwnd := 0
}

OnShowConfigHelp(ctrl, *)
{
    helpText :="修飾キーは ^!+# (Ctrl/Alt/Shift/Win)を頭に付けます。`n(例 Ctrl+Alt+F9 = ^!F9)`nサイズ登録は最前面ウインドウのサイズを保存します。"

    MsgBox helpText, "設定ヘルプ", "Iconi"
}

LoadOffsetToGui(ctrl, *)
{
    MyGui := ctrl.Gui
    global OffsetConfig, DefaultW, DefaultH, ConfigFile, DefaultSection

    exe := MyGui["AppChoice"].Text

    if OffsetConfig.Has(exe)
    {
        ; 登録済みアプリ
        MyGui["OffsetW"].Text := OffsetConfig[exe].w
        MyGui["OffsetH"].Text := OffsetConfig[exe].h
    }
    else
    {
        ; 未登録アプリ → INIのUnregisteredを読み込む
        w := IniRead(ConfigFile, DefaultSection, "Width", DefaultW)
        h := IniRead(ConfigFile, DefaultSection, "Height", DefaultH)

        MyGui["OffsetW"].Text := w
        MyGui["OffsetH"].Text := h
    }
}

SaveOffset(ctrl, *)
{
    MyGui := ctrl.Gui

    if !ApplyGuiSettings(MyGui)
        return

    MyGui.Destroy()
    global ConfigGuiHwnd
    ConfigGuiHwnd := 0
}

UpdateOffset(ctrl, *)
{
    MyGui := ctrl.Gui

    if !ApplyGuiSettings(MyGui)
        return

    CascadeWindows()
    ForceRedrawAll()
}

ApplyGuiSettings(MyGui)
{
    global OffsetConfig, ConfigFile, Resize
    global DefaultSection
    global CascadeHotkey, GuiHotkey

    MyGui.Submit(false)

    exe := Trim(MyGui["AppChoice"].Text)
    if (exe = "")
        exe := DefaultSection

    try
    {
        w := Integer(MyGui["OffsetW"].Text)
        h := Integer(MyGui["OffsetH"].Text)
    }
    catch
    {
        MsgBox "ずらし幅または高さが数値ではありません。"
        return false
    }

    newCascadeHotkey := Trim(MyGui["CascadeHotkey"].Text)
    newGuiHotkey := Trim(MyGui["GuiHotkey"].Text)

    if (newCascadeHotkey = "")
        newCascadeHotkey := "F9"
    if (newGuiHotkey = "")
        newGuiHotkey := "F10"

    if (newCascadeHotkey = newGuiHotkey)
    {
        MsgBox "Cascade と GUI に同じホットキーは設定できません。"
        return false
    }

    ; まずホットキーの妥当性を検証
    if !ValidateHotkeyPair(newCascadeHotkey, newGuiHotkey)
        return false

    ; オフセット保存
    OffsetConfig[exe] := { w: w, h: h }

    IniWrite(w, ConfigFile, exe, "Width")
    IniWrite(h, ConfigFile, exe, "Height")

    ; サイズ合わせ設定保存
    Resize := MyGui["Resize"].Value
    IniWrite(Resize ? 1 : 0, ConfigFile, "Options", "Resize")

    ; Keybind保存
    CascadeHotkey := newCascadeHotkey
    GuiHotkey := newGuiHotkey

    IniWrite(CascadeHotkey, ConfigFile, "Keybind", "Cascade")
    IniWrite(GuiHotkey, ConfigFile, "Keybind", "Gui")

    ; 再登録
    RegisterHotkeys()

    return true
}

; ===============================
; Keybind関連
; ===============================
RegisterHotkeys()
{
    global CascadeHotkey, GuiHotkey
    global RegisteredCascadeHotkey, RegisteredGuiHotkey

    ; 既存ホットキー解除
    if (RegisteredCascadeHotkey != "")
    {
        try Hotkey(RegisteredCascadeHotkey, "Off")
    }

    if (RegisteredGuiHotkey != "")
    {
        try Hotkey(RegisteredGuiHotkey, "Off")
    }

    ; 重複防止
    if (CascadeHotkey = GuiHotkey)
    {
        MsgBox "Cascade と GUI に同じホットキーが設定されていたため、既定値(F9/F10)に戻します。"
        CascadeHotkey := "F9"
        GuiHotkey := "F10"

        IniWrite(CascadeHotkey, ConfigFile, "Keybind", "Cascade")
        IniWrite(GuiHotkey, ConfigFile, "Keybind", "Gui")
    }

    ; 新規登録
    try
    {
        Hotkey(CascadeHotkey, CascadeWindows, "On")
        RegisteredCascadeHotkey := CascadeHotkey
    }
    catch
    {
        MsgBox "Cascade 用ホットキーが無効です。既定値 F9 を使用します。`n`n設定値: " CascadeHotkey
        CascadeHotkey := "F9"
        IniWrite(CascadeHotkey, ConfigFile, "Keybind", "Cascade")
        Hotkey(CascadeHotkey, CascadeWindows, "On")
        RegisteredCascadeHotkey := CascadeHotkey
    }

    try
    {
        Hotkey(GuiHotkey, ShowConfigGui, "On")
        RegisteredGuiHotkey := GuiHotkey
    }
    catch
    {
        MsgBox "GUI 用ホットキーが無効です。既定値 F10 を使用します。`n`n設定値: " GuiHotkey
        GuiHotkey := "F10"
        IniWrite(GuiHotkey, ConfigFile, "Keybind", "Gui")
        Hotkey(GuiHotkey, ShowConfigGui, "On")
        RegisteredGuiHotkey := GuiHotkey
    }
}

ValidateHotkeyPair(testCascade, testGui)
{
    if (testCascade = testGui)
    {
        MsgBox "Cascade と GUI に同じホットキーは設定できません。"
        return false
    }

    ; 一時登録して妥当性チェック
    ; 成功したらすぐ解除する
    try
    {
        Hotkey(testCascade, TempHotkeyHandler, "On")
        Hotkey(testCascade, "Off")
    }
    catch
    {
        MsgBox "Cascade ホットキーが無効です:`n" testCascade
        return false
    }

    try
    {
        Hotkey(testGui, TempHotkeyHandler, "On")
        Hotkey(testGui, "Off")
    }
    catch
    {
        MsgBox "GUI ホットキーが無効です:`n" testGui
        return false
    }

    return true
}

TempHotkeyHandler(*)
{
    ; 妥当性チェック用のダミー
}

; ===============================
; サイズ登録
; ===============================
RegisterSize(ctrl, *)
{
    global ConfigFile, DefaultSection
    global GlobalSizeW, GlobalSizeH

    hwnd := GetTopValidWindow()

    if !hwnd
        return

    WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)

    GlobalSizeW := w
    GlobalSizeH := h

    IniWrite(w, ConfigFile, DefaultSection, "SizeW")
    IniWrite(h, ConfigFile, DefaultSection, "SizeH")
}

; ===============================
; 再描画
; ===============================
ForceRedrawAll()
{
    winList := WinGetList()

    for hwnd in winList
    {
        if WinGetMinMax("ahk_id " hwnd) != 0
            continue

        DllCall("RedrawWindow"
            , "ptr", hwnd
            , "ptr", 0
            , "ptr", 0
            , "uint", 0x85)
    }
}

; ===============================
; 設定読み込み
; ===============================
LoadConfig()
{
    global OffsetConfig, ConfigFile
    global DefaultSection, DefaultW, DefaultH
    global GlobalSizeW, GlobalSizeH
    global Resize
    global CascadeHotkey, GuiHotkey

    ; iniが無い場合のみ作成
    if !FileExist(ConfigFile)
    {
        IniWrite(DefaultW, ConfigFile, DefaultSection, "Width")
        IniWrite(DefaultH, ConfigFile, DefaultSection, "Height")
        IniWrite("F9", ConfigFile, "Keybind", "Cascade")
        IniWrite("F10", ConfigFile, "Keybind", "Gui")
        IniWrite(0, ConfigFile, "Options", "Resize")
    }

    ; デフォルト値読み込み
    DefaultW := Integer(IniRead(ConfigFile, DefaultSection, "Width", 24))
    DefaultH := Integer(IniRead(ConfigFile, DefaultSection, "Height", 24))

    GlobalSizeW := IniRead(ConfigFile, DefaultSection, "SizeW", "")
    GlobalSizeH := IniRead(ConfigFile, DefaultSection, "SizeH", "")

    Resize := Integer(IniRead(ConfigFile, "Options", "Resize", 0)) != 0

    CascadeHotkey := Trim(IniRead(ConfigFile, "Keybind", "Cascade", "F9"))
    GuiHotkey := Trim(IniRead(ConfigFile, "Keybind", "Gui", "F10"))

    OffsetConfig := Map()

    sections := IniRead(ConfigFile)

    for section in StrSplit(sections, "`n")
    {
        section := Trim(section, " []`r`t")

        if (section = "" || section = DefaultSection || section = "Keybind" || section = "Options")
            continue

        w := IniRead(ConfigFile, section, "Width", DefaultW)
        h := IniRead(ConfigFile, section, "Height", DefaultH)

        OffsetConfig[section] := { w: Integer(w), h: Integer(h) }
    }
}
