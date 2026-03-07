/*
============================================================
Window Cascade Tool for AutoHotkey v2
============================================================

Author: k1segawa
License: MIT
Version: 1.0

Description:
This script cascades open windows using custom offsets.
Offsets can be configured per application.

Hotkeys:
F9  - Cascade all windows
F10 - Set offset for active window

Features:
- Per-application offset settings
- DEFAULT fallback value (24x24)
- Windows 11 compatible
- Skips minimized, tool, cloaked, child, and fullscreen windows

Config File:
WindowCascade.ini (created automatically)

============================================================
*/

#Requires AutoHotkey v2.0

; ==============================
; Window Cascade Tool
; Press F9 to cascade windows
; Press F10 to set offset for active window
; ==============================

configFile := A_ScriptDir "\WindowCascade.ini"
defaultSection := "DEFAULT"
windowOffsetMap := Map()

InitializeConfig()
LoadOffsetConfig()

F9::CascadeWindows()
F10::OpenOffsetEditor()

; ------------------------------
; Create INI file if not exists
; ------------------------------
InitializeConfig()
{
    global configFile, defaultSection

    if !FileExist(configFile)
    {
        IniWrite(24, configFile, defaultSection, "Width")
        IniWrite(24, configFile, defaultSection, "Height")
    }
}

; ------------------------------
; Load offsets from INI
; ------------------------------
LoadOffsetConfig()
{
    global configFile, windowOffsetMap

    windowOffsetMap.Clear()

    sections := IniRead(configFile)

    for section in StrSplit(sections, "`n")
    {
        if (section = "" || section = "DEFAULT")
            continue

        width := IniRead(configFile, section, "Width", 24)
        height := IniRead(configFile, section, "Height", 24)

        windowOffsetMap[section] := { w: width+0, h: height+0 }
    }
}

; ------------------------------
; Open offset editor GUI
; ------------------------------
OpenOffsetEditor()
{
    global configFile, defaultSection

    activeExe := WinGetProcessName("A")

    width := IniRead(configFile, activeExe, "Width", "")
    height := IniRead(configFile, activeExe, "Height", "")

    if (width = "")
        width := IniRead(configFile, defaultSection, "Width", 24)

    if (height = "")
        height := IniRead(configFile, defaultSection, "Height", 24)

    myGui := Gui()
    myGui.Title := "Set Window Offset"

    myGui.AddText(, "Width:")
    widthEdit := myGui.AddEdit("w100", width)

    myGui.AddText(, "Height:")
    heightEdit := myGui.AddEdit("w100", height)

    saveButton := myGui.AddButton("default", "Save")

    saveButton.OnEvent("Click", (*) =>
    (
        IniWrite(widthEdit.Value, configFile, activeExe, "Width"),
        IniWrite(heightEdit.Value, configFile, activeExe, "Height"),
        LoadOffsetConfig(),
        myGui.Destroy()
    ))

    myGui.Show()
}

; ------------------------------
; Cascade windows
; ------------------------------
CascadeWindows()
{
    global windowOffsetMap, defaultSection, configFile

    winList := WinGetList()
    screenW := A_ScreenWidth
    screenH := A_ScreenHeight

    validWindows := []

    ; Collect valid windows only
    Loop winList.Length
    {
        hwnd := winList[winList.Length - A_Index + 1]

        if !WinExist("ahk_id " hwnd)
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

    totalX := 0
    totalY := 0

    for hwnd in validWindows
    {
        exe := WinGetProcessName("ahk_id " hwnd)

        if windowOffsetMap.Has(exe)
        {
            dx := windowOffsetMap[exe].w
            dy := windowOffsetMap[exe].h
        }
        else
        {
            dx := IniRead(configFile, defaultSection, "Width", 24)
            dy := IniRead(configFile, defaultSection, "Height", 24)
        }

        WinMove(totalX, totalY, , , "ahk_id " hwnd)

        totalX += dx
        totalY += dy
    }
}