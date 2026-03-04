/*
============================================================
Window Cascade Tool for AutoHotkey v2
============================================================

Author: k1segawa
License: MIT
Version: 1.2

Added:
- Update button (apply instantly without closing)
- Added checkbox to match topmost window size
- Force redraw on update

Overview:
Cascades open windows using specified offset values.
You can configure offset width and height per application.

Hotkeys:
F9  - Reposition all windows
F10 - Set offset for the active window

Features:
- Per-application configuration supported
- Uses default value (24x24) when not registered
- Windows 10 / 11 compatible
- Excludes minimized / tool / child / fullscreen / cloaked / settings GUI windows

Configuration file:
cascade_offsets.ini (auto-generated)

============================================================
*/

#Requires AutoHotkey v2.0

global OffsetConfig := Map()
global ConfigFile := A_ScriptDir "\cascade_offsets.ini"
global DefaultSection := "Unregistered"
global DefaultW := 24
global DefaultH := 24
global MatchTopMostSize := false

LoadConfig()

F9::CascadeWindows()
F10::ShowConfigGui()

; ===============================
; Cascade processing (cumulative mode)
; ===============================
CascadeWindows()
{
    global OffsetConfig, DefaultSection, ConfigFile
    global MatchTopMostSize, DefaultW, DefaultH

    winList := WinGetList()
    screenW := A_ScreenWidth
    screenH := A_ScreenHeight

    validWindows := []
    guiHwnd := 0

    ; If GUI exists, get its hwnd
    for hwnd in winList
    {
        title := WinGetTitle("ahk_id " hwnd)
        if (title = "Cascade Offset Settings")
        {
            guiHwnd := hwnd
            break
        }
    }

    Loop winList.Length
    {
        hwnd := winList[winList.Length - A_Index + 1]  ; back → front

        ; Exclude AutoHotkey internal windows
        if !WinExist("ahk_id " hwnd)
            continue

        ; Exclude GUI window
        if hwnd = guiHwnd
            continue

        ; Exclude minimized windows
        if WinGetMinMax("ahk_id " hwnd) = -1
            continue

        ; Exclude windows that have a parent (remove child windows)
        if DllCall("GetParent", "ptr", hwnd)
            continue

        ; Exclude tool windows
        exStyle := DllCall("GetWindowLongPtr", "ptr", hwnd, "int", -20, "ptr")
        if (exStyle & 0x80)  ; WS_EX_TOOLWINDOW
            continue

        ; Exclude cloaked windows (UWP / hidden virtual desktop)
        cloaked := 0
        DllCall("dwmapi\DwmGetWindowAttribute"
            , "ptr", hwnd
            , "int", 14  ; DWMWA_CLOAKED
            , "int*", cloaked
            , "int", 4)
        if cloaked
            continue

        WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " hwnd)

        ; Exclude zero-size windows
        if (ww <= 0 || wh <= 0)
            continue

        ; Exclude fullscreen windows
        if (ww >= screenW && wh >= screenH)
            continue

        validWindows.Push(hwnd)
    }

    ;  Get the topmost window excluding GUI
    if MatchTopMostSize && validWindows.Length > 0
    {
        topmost := validWindows[validWindows.Length]
        WinGetPos(&fx, &fy, &fw, &fh, "ahk_id " topmost)
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
            dx := IniRead(ConfigFile, DefaultSection, "Width", DefaultW)
            dy := IniRead(ConfigFile, DefaultSection, "Height", DefaultH)
        }

        if MatchTopMostSize
            WinMove(totalX, totalY, fw, fh, "ahk_id " hwnd)
        else
            WinMove(totalX, totalY, , , "ahk_id " hwnd)

        totalX += dx
        totalY += dy
    }
}

; ===============================
; Settings GUI
; ===============================
ShowConfigGui()
{
    global OffsetConfig, DefaultW, DefaultH, MatchTopMostSize

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

    ;  Initial state is unselected (empty display)
    ddl.Value := 0

    MyGui.Add("Text", , "Offset Width:")
    MyGui.Add("Edit", "w100 vOffsetW", DefaultW)

    MyGui.Add("Text", , "Offset Height:")
    MyGui.Add("Edit", "w100 vOffsetH", DefaultH)

    chk := MyGui.Add("Checkbox", "vMatchTopMost", "Match topmost window size")
    chk.Value := MatchTopMostSize

    btnSave := MyGui.Add("Button", "Default", "Save")
    btnUpdate := MyGui.Add("Button", "x+10", "Update")

    ddl.OnEvent("Change", LoadOffsetToGui)
    btnSave.OnEvent("Click", SaveOffset)
    btnUpdate.OnEvent("Click", UpdateOffset)

    MyGui.Show()
}

LoadOffsetToGui(ctrl, *)
{
    MyGui := ctrl.Gui
    global OffsetConfig, DefaultW, DefaultH

    exe := MyGui["AppChoice"].Text

    if OffsetConfig.Has(exe)
    {
        ; Registered application
        MyGui["OffsetW"].Text := OffsetConfig[exe].w
        MyGui["OffsetH"].Text := OffsetConfig[exe].h
    }
    else
    {
        ; Unregistered application → load Unregistered section from INI
        w := IniRead(ConfigFile, DefaultSection, "Width", DefaultW)
        h := IniRead(ConfigFile, DefaultSection, "Height", DefaultH)

        MyGui["OffsetW"].Text := w
        MyGui["OffsetH"].Text := h
    }
}

SaveOffset(ctrl, *)
{
    MyGui := ctrl.Gui
    global OffsetConfig, ConfigFile, MatchTopMostSize

    MyGui.Submit()

    exe := MyGui["AppChoice"].Text

    if (exe = "")
        exe := DefaultSection

    w := Integer(MyGui["OffsetW"].Text)
    h := Integer(MyGui["OffsetH"].Text)

    OffsetConfig[exe] := { w: w, h: h }

    IniWrite(w, ConfigFile, exe, "Width")
    IniWrite(h, ConfigFile, exe, "Height")

    MatchTopMostSize := MyGui["MatchTopMost"].Value

    MyGui.Destroy()
}

UpdateOffset(ctrl, *)
{
    MyGui := ctrl.Gui
    global OffsetConfig, ConfigFile, MatchTopMostSize

    MyGui.Submit(false)

    exe := MyGui["AppChoice"].Text

    if (exe = "")
        exe := DefaultSection

    w := Integer(MyGui["OffsetW"].Text)
    h := Integer(MyGui["OffsetH"].Text)

    OffsetConfig[exe] := { w: w, h: h }

    IniWrite(w, ConfigFile, exe, "Width")
    IniWrite(h, ConfigFile, exe, "Height")

    MatchTopMostSize := MyGui["MatchTopMost"].Value

    CascadeWindows()
    ForceRedrawAll()
}

; ===============================
; Force redraw
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
