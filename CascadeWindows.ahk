/*
============================================================
Window Cascade Tool for AutoHotkey v2
============================================================

Author: k1segawa
License: MIT
Version: 1.0

Description:
Cascades open windows using a specified offset amount.
You can configure the width and height offset per application.

Hotkeys:
F9  - Reposition all windows
F10 - Set offset for the active window

Features:
- Per-application custom settings
- Uses default value (24x24) for unregistered apps
- Windows 11 compatible
- Skips minimized / tool / child / fullscreen windows

Config file:
cascade_offsets.ini (auto-created)

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
; Cascade processing (cumulative method)
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
        hwnd := winList[winList.Length - A_Index + 1]  ; Back to front (Z-order)

        if !WinExist("ahk_id " hwnd)
            continue

        ; Skip minimized windows
        if WinGetMinMax("ahk_id " hwnd) = -1
            continue

        ; Skip windows that have a parent (remove child windows)
        if DllCall("GetParent", "ptr", hwnd)
            continue

        ; Skip tool windows
        exStyle := DllCall("GetWindowLongPtr", "ptr", hwnd, "int", -20, "ptr")
        if (exStyle & 0x80)
            continue

        ; Skip cloaked windows (UWP / hidden virtual desktop)
        cloaked := 0
        DllCall("dwmapi\DwmGetWindowAttribute"
            , "ptr", hwnd
            , "int", 14
            , "int*", cloaked
            , "int", 4)
        if cloaked
            continue

        WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " hwnd)

        ; Skip zero size windows
        if (ww <= 0 || wh <= 0)
            continue

        ; Skip fullscreen windows
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
; Configuration GUI
; ===============================
ShowConfigGui()
{
    global OffsetConfig, DefaultW, DefaultH

    MyGui := Gui("+Resize", "Cascade Offset Settings")

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

    MyGui.Add("Text", , "Select Application:")
    ddl := MyGui.Add("DropDownList", "w300 vAppChoice", exeArray)

    MyGui.Add("Text", , "Offset Width:")
    MyGui.Add("Edit", "w100 vOffsetW")

    MyGui.Add("Text", , "Offset Height:")
    MyGui.Add("Edit", "w100 vOffsetH")

    btnSave := MyGui.Add("Button", "Default", "Save")

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
        ; Registered application
        MyGui["OffsetW"].Text := OffsetConfig[exe].w
        MyGui["OffsetH"].Text := OffsetConfig[exe].h
    }
    else
    {
        ; Unregistered application → read from INI
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

    MsgBox "Saved: " exe

    MyGui.Destroy()
}


; ===============================
; Load configuration
; ===============================
LoadConfig()
{
    global OffsetConfig, ConfigFile
    global DefaultSection, DefaultW, DefaultH

    ; Create INI only if it does not exist
    if !FileExist(ConfigFile)
    {
        IniWrite(DefaultW, ConfigFile, DefaultSection, "Width")
        IniWrite(DefaultH, ConfigFile, DefaultSection, "Height")
    }

    ; Load default values
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

