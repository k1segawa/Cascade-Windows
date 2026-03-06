/*
============================================================
Window Cascade Tool for AutoHotkey v2
============================================================

Author: k1segawa
License: MIT
Version: 1.3

Added:
- Update button (apply instantly without closing)
- Option to match registered window size
- Redraw after update
- Size registration button (save frontmost window size)

Overview:
Cascade open windows using configurable offset values.
You can set different horizontal and vertical offsets
for each application.

Hotkeys:
F9  - Cascade all windows
F10 - Configure offset for the active window

Features:
- Per-application configuration
- Uses default value (24x24) if not registered
- Windows 10 / 11 compatible
- Automatically skips:
  minimized / tool / child / fullscreen / cloaked / config GUI

Configuration File:
cascade_offsets.ini (created automatically)

============================================================
*/

#Requires AutoHotkey v2.0

global OffsetConfig := Map()
global ConfigFile := A_ScriptDir "\cascade_offsets.ini"
global DefaultSection := "Unregistered"
global DefaultW := 24
global DefaultH := 24
global MatchTopMostSize := false

global GlobalSizeW := ""
global GlobalSizeH := ""

global ConfigGuiHwnd := 0

LoadConfig()

F9::CascadeWindows()
F10::ShowConfigGui()

; ===============================
; Get valid windows
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
        hwnd := winList[winList.Length - A_Index + 1]  ; back → front

        ; Exclude invalid AutoHotkey window
        if !WinExist("ahk_id " hwnd)
            continue

        ; Exclude configuration GUI
        if hwnd = ConfigGuiHwnd
            continue

        ; Exclude minimized windows
        if WinGetMinMax("ahk_id " hwnd) = -1
            continue

        ; Exclude child windows
        if DllCall("GetParent", "ptr", hwnd)
            continue

        ; Exclude tool windows
        exStyle := DllCall("GetWindowLongPtr", "ptr", hwnd, "int", -20, "ptr")
        if (exStyle & 0x80)  ; WS_EX_TOOLWINDOW
            continue

        ; Exclude cloaked windows (UWP / virtual desktop background)
        cloaked := 0
        DllCall("dwmapi\DwmGetWindowAttribute"
            , "ptr", hwnd
            , "int", 14  ; DWMWA_CLOAKED
            , "int*", cloaked
            , "int", 4)

        if cloaked
            continue

        WinGetPos(&x,&y,&w,&h,"ahk_id " hwnd)

        ; Exclude zero-sized windows
        if (w <= 0 || h <= 0)
            continue

        ; Exclude fullscreen windows
        if (w >= screenW && h >= screenH)
            continue

        valid.Push(hwnd)
    }

    return valid
}

; ===============================
; Get frontmost valid window
; ===============================
GetTopValidWindow()
{
    valid := GetValidWindows()

    if valid.Length = 0
        return 0

    return valid[valid.Length]
}

; ===============================
; Cascade processing
; ===============================
CascadeWindows()
{
    global OffsetConfig, DefaultSection, ConfigFile
    global MatchTopMostSize, DefaultW, DefaultH
    global GlobalSizeW, GlobalSizeH

    validWindows := GetValidWindows()

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

        if MatchTopMostSize && GlobalSizeW != "" && GlobalSizeH != ""
            WinMove(totalX, totalY, GlobalSizeW, GlobalSizeH, "ahk_id " hwnd)
        else
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
    global OffsetConfig, DefaultW, DefaultH, MatchTopMostSize
    global ConfigGuiHwnd

    MyGui := Gui("+Resize", "Cascade Offset Settings")

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

    MyGui.Add("Text", , "Select application:")
    ddl := MyGui.Add("DropDownList", "w300 vAppChoice", exeArray)

    ; ★ Initial state is unselected (empty display)
    ddl.Value := 0

    MyGui.Add("Text", , "Horizontal offset:")
    MyGui.Add("Edit", "w100 vOffsetW", DefaultW)

    MyGui.Add("Text", , "Vertical offset:")
    MyGui.Add("Edit", "w100 vOffsetH", DefaultH)

    chk := MyGui.Add("Checkbox", "vMatchTopMost", "Match registered window size")
    chk.Value := MatchTopMostSize

    btnSave := MyGui.Add("Button", "Default", "Save")
    btnUpdate := MyGui.Add("Button", "x+10", "Update")
    btnRegister := MyGui.Add("Button", "x+10", "Register front window size")

    ddl.OnEvent("Change", LoadOffsetToGui)
    btnSave.OnEvent("Click", SaveOffset)
    btnUpdate.OnEvent("Click", UpdateOffset)
    btnRegister.OnEvent("Click", RegisterSize)

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
        ; Unregistered application → load from INI Unregistered section
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

RegisterSize(ctrl, *)
{
    global ConfigFile, DefaultSection
    global GlobalSizeW, GlobalSizeH

    hwnd := GetTopValidWindow()

    if !hwnd
        return

    WinGetPos(&x,&y,&w,&h,"ahk_id " hwnd)

    GlobalSizeW := w
    GlobalSizeH := h

    IniWrite(w, ConfigFile, DefaultSection, "SizeW")
    IniWrite(h, ConfigFile, DefaultSection, "SizeH")
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
    global GlobalSizeW, GlobalSizeH

    ; Create ini only if it does not exist
    if !FileExist(ConfigFile)
    {
        IniWrite(DefaultW, ConfigFile, DefaultSection, "Width")
        IniWrite(DefaultH, ConfigFile, DefaultSection, "Height")
    }

    ; Load default values
    DefaultW := Integer(IniRead(ConfigFile, DefaultSection, "Width", 24))
    DefaultH := Integer(IniRead(ConfigFile, DefaultSection, "Height", 24))

    GlobalSizeW := IniRead(ConfigFile, DefaultSection, "SizeW", "")
    GlobalSizeH := IniRead(ConfigFile, DefaultSection, "SizeH", "")

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
