/*
============================================================
Window Cascade Tool for AutoHotkey v2
============================================================

Author: k1segawa
License: MIT
Version: 1.1

Added:
- Update button (apply instantly without closing)
- Added checkbox to match front window size
- Force redraw on update

============================================================
*/

#Requires AutoHotkey v2.0

global OffsetConfig := Map()
global ConfigFile := A_ScriptDir "\cascade_offsets.ini"
global DefaultSection := "Unregistered"
global DefaultW := 24
global DefaultH := 24
global MatchFrontSize := false

LoadConfig()

F9::CascadeWindows()
F10::ShowConfigGui()

; ===============================
; Cascade processing (cumulative mode)
; ===============================
CascadeWindows()
{
    global OffsetConfig, DefaultSection, ConfigFile
    global MatchFrontSize, DefaultW, DefaultH

    winList := WinGetList()
    screenW := A_ScreenWidth
    screenH := A_ScreenHeight

    validWindows := []
    guiHwnd := 0

    ; Get GUI hwnd if it exists
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
        hwnd := winList[winList.Length - A_Index + 1]

        if !WinExist("ahk_id " hwnd)
            continue

        if hwnd = guiHwnd
            continue

        if WinGetMinMax("ahk_id " hwnd) = -1
            continue

        if DllCall("GetParent", "ptr", hwnd)
            continue

        exStyle := DllCall("GetWindowLongPtr", "ptr", hwnd, "int", -20, "ptr")
        if (exStyle & 0x80)
            continue

        cloaked := 0
        DllCall("dwmapi\DwmGetWindowAttribute"
            , "ptr", hwnd
            , "int", 14
            , "int*", cloaked
            , "int", 4)
        if cloaked
            continue

        WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " hwnd)

        if (ww <= 0 || wh <= 0)
            continue

        if (ww >= screenW && wh >= screenH)
            continue

        validWindows.Push(hwnd)
    }

    ; ★ Get front window excluding GUI
    if MatchFrontSize && validWindows.Length > 0
    {
        front := validWindows[validWindows.Length]
        WinGetPos(&fx, &fy, &fw, &fh, "ahk_id " front)
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
            dx := DefaultW
            dy := DefaultH
        }

        if MatchFrontSize
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
    global OffsetConfig, DefaultW, DefaultH, MatchFrontSize

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

    ; ★ Initial state is unselected (empty display)
    ddl.Value := 0

    MyGui.Add("Text", , "Offset Width:")
    MyGui.Add("Edit", "w100 vOffsetW", DefaultW)

    MyGui.Add("Text", , "Offset Height:")
    MyGui.Add("Edit", "w100 vOffsetH", DefaultH)

    chk := MyGui.Add("Checkbox", "vMatchFront", "Match topmost window size")
    chk.Value := MatchFrontSize

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
        MyGui["OffsetW"].Text := OffsetConfig[exe].w
        MyGui["OffsetH"].Text := OffsetConfig[exe].h
    }
    else
    {
        MyGui["OffsetW"].Text := DefaultW
        MyGui["OffsetH"].Text := DefaultH
    }
}

SaveOffset(ctrl, *)
{
    MyGui := ctrl.Gui
    global OffsetConfig, ConfigFile, MatchFrontSize

    MyGui.Submit()

    exe := MyGui["AppChoice"].Text
    w := Integer(MyGui["OffsetW"].Text)
    h := Integer(MyGui["OffsetH"].Text)

    OffsetConfig[exe] := { w: w, h: h }

    IniWrite(w, ConfigFile, exe, "Width")
    IniWrite(h, ConfigFile, exe, "Height")

    MatchFrontSize := MyGui["MatchFront"].Value

    MsgBox "Saved: " exe
    MyGui.Destroy()
}

UpdateOffset(ctrl, *)
{
    MyGui := ctrl.Gui
    global OffsetConfig, ConfigFile, MatchFrontSize

    MyGui.Submit(false)

    exe := MyGui["AppChoice"].Text
    w := Integer(MyGui["OffsetW"].Text)
    h := Integer(MyGui["OffsetH"].Text)

    OffsetConfig[exe] := { w: w, h: h }

    IniWrite(w, ConfigFile, exe, "Width")
    IniWrite(h, ConfigFile, exe, "Height")

    MatchFrontSize := MyGui["MatchFront"].Value

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

    if !FileExist(ConfigFile)
    {
        IniWrite(DefaultW, ConfigFile, DefaultSection, "Width")
        IniWrite(DefaultH, ConfigFile, DefaultSection, "Height")
    }

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

