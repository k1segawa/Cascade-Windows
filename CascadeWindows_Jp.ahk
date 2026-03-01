/*
============================================================
AutoHotkey v2 用 ウインドウカスケードツール
============================================================

作者: k1segawa
ライセンス: MIT
バージョン: 1.0

概要:
開いているウインドウを指定したずらし量で
カスケード配置します。
アプリごとにずらす幅と高さを設定可能です。

ホットキー:
F9  - すべてのウインドウを再配置
F10 - アクティブウインドウのずらし量を設定

特徴:
- アプリごとの個別設定対応
- 未登録時はデフォルト値(24x24)使用
- Windows 11対応
- 最小化 / ツール / 子 / フルスクリーン除外

設定ファイル:
WindowCascade.ini（自動生成）

============================================================
*/

#Requires AutoHotkey v2.0

global OffsetConfig := Map()
global ConfigFile := A_ScriptDir "\cascade_offsets.ini"
global DefaultSection := "Unregistered"
global DefaultW := 24
global DefaultH := 24

LoadConfig()

F9::CascadeWindows()
F10::ShowConfigGui()


; ===============================
; カスケード処理（累積方式）
; ===============================
CascadeWindows()
{
    global OffsetConfig, DefaultSection, ConfigFile

    winList := WinGetList()
    screenW := A_ScreenWidth
    screenH := A_ScreenHeight

    validWindows := []

    Loop winList.Length
    {
        hwnd := winList[winList.Length - A_Index + 1]  ; 奥→手前

        if !WinExist("ahk_id " hwnd)
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

        WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " hwnd)

        ; サイズ0除外
        if (ww <= 0 || wh <= 0)
            continue

        ; フルスクリーン除外
        if (ww >= screenW && wh >= screenH)
            continue

        validWindows.Push(hwnd)
    }

    totalX := 0
    totalY := 0

    for hwnd in validWindows
    {
        exe := WinGetProcessName("ahk_id " hwnd)

        if OffsetConfig.Has(exe)
        {
            dx := OffsetConfig[exe].w
            dy := OffsetConfig[exe].h
        }
        else
        {
            dx := IniRead(ConfigFile, DefaultSection, "Width", 24)
            dy := IniRead(ConfigFile, DefaultSection, "Height", 24)
        }

        WinMove(totalX, totalY, , , "ahk_id " hwnd)

        totalX += dx
        totalY += dy
    }
}

; ===============================
; 設定GUI
; ===============================
ShowConfigGui()
{
    global OffsetConfig, DefaultW, DefaultH

    MyGui := Gui("+Resize", "カスケードずらし量設定")

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

    MyGui.Add("Text", , "ずらす幅:")
    MyGui.Add("Edit", "w100 vOffsetW")

    MyGui.Add("Text", , "ずらす高さ:")
    MyGui.Add("Edit", "w100 vOffsetH")

    btnSave := MyGui.Add("Button", "Default", "保存")

    ddl.OnEvent("Change", (*) => LoadOffsetToGui(MyGui))
    btnSave.OnEvent("Click", (*) => SaveOffset(MyGui))

    MyGui.Show()
}


LoadOffsetToGui(MyGui)
{
    global OffsetConfig, ConfigFile, DefaultSection

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
        w := IniRead(ConfigFile, DefaultSection, "Width", 24)
        h := IniRead(ConfigFile, DefaultSection, "Height", 24)

        MyGui["OffsetW"].Text := w
        MyGui["OffsetH"].Text := h
    }
}

SaveOffset(MyGui)
{
    global OffsetConfig, ConfigFile

    MyGui.Submit()

    exe := MyGui["AppChoice"].Text
    w := Integer(MyGui["OffsetW"].Text)
    h := Integer(MyGui["OffsetH"].Text)

    OffsetConfig[exe] := { w: w, h: h }

    IniWrite(w, ConfigFile, exe, "Width")
    IniWrite(h, ConfigFile, exe, "Height")

    MsgBox "保存しました: " exe

    MyGui.Destroy()
}


; ===============================
; 設定読み込み
; ===============================
LoadConfig()
{
    global OffsetConfig, ConfigFile
    global DefaultSection, DefaultW, DefaultH

    ; iniが無い場合のみ作成
    if !FileExist(ConfigFile)
    {
        IniWrite(DefaultW, ConfigFile, DefaultSection, "Width")
        IniWrite(DefaultH, ConfigFile, DefaultSection, "Height")
    }

    ; デフォルト値読み込み
    DefaultW := Integer(IniRead(ConfigFile, DefaultSection, "Width", 24))
    DefaultH := Integer(IniRead(ConfigFile, DefaultSection, "Height", 24))

    sections := IniRead(ConfigFile)

    for section in StrSplit(sections, "`n")
    {
        if section = "" || section = DefaultSection
            continue

        w := IniRead(ConfigFile, section, "Width", DefaultW)
        h := IniRead(ConfigFile, section, "Height", DefaultH)

        OffsetConfig[section] := { w: Integer(w), h: Integer(h) }
    }
}