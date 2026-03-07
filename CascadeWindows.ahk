/*
============================================================
AutoHotkey v2 Window Cascade Tool
============================================================

Author: k1segawa
License: MIT
Version: 1.4

Added:
- Update button (apply without closing / allow hotkey change)
- Size register button (save size of front window)
- Resize option added
- Hotkeys configurable

Overview:
Open windows are stacked (cascaded) using the specified offsets.
Offset width and height can be configured per application.
Optionally all windows can be resized to the registered size.

Default Hotkeys:
F9  - Reposition all windows
F10 - Open settings GUI (x = cancel)

Features:
- Per-application configuration
- Default value (24x24) used when not registered
- Front window size can be registered and used for resizing
- Windows 10 / 11 supported
- Excluded windows:
  Minimized / Tool / Child / Fullscreen / Cloaked / Snap /
  Settings GUI (also excluded from app selection and size register) /
  MsgBox from this script

Exit:
Task tray -> right-click [H] icon -> Exit

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
global Resize := false

global GlobalSizeW := ""
global GlobalSizeH := ""

global ConfigGuiHwnd := 0

; -------------------------------
; Keybind related
; -------------------------------
global CascadeHotkey := "F9"
global GuiHotkey := "F10"
global RegisteredCascadeHotkey := ""
global RegisteredGuiHotkey := ""

LoadConfig()
RegisterHotkeys()

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
        hwnd := winList[winList.Length - A_Index + 1]  ; back -> front

        ; Exclude AutoHotKey
        if !WinExist("ahk_id " hwnd)
            continue

        ; Exclude windows belonging to this script
        if WinGetPID("ahk_id " hwnd) = DllCall("GetCurrentProcessId")
            continue

        ; Exclude GUI
        if hwnd = ConfigGuiHwnd
            continue

        ; Exclude minimized windows
        if WinGetMinMax("ahk_id " hwnd) = -1
            continue

        ; Exclude windows that have a parent (child windows)
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
            , "int", 14
            , "int*", cloaked
            , "int", 4)

        if cloaked
            continue

        WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)

        ; Exclude zero-size windows
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
; Get front valid window
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
            ; Registered application
            dx := OffsetConfig[exe].w
            dy := OffsetConfig[exe].h
        }
        else
        {
            ; Unregistered application -> read Unregistered from INI
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
; Settings GUI
; ===============================
ShowConfigGui(*)
{
    global OffsetConfig, DefaultW, DefaultH, Resize
    global ConfigGuiHwnd
    global CascadeHotkey, GuiHotkey

    MyGui := Gui("+Resize", "Settings")

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
    ddl.Value := 0

    MyGui.Add("Text", , "Offset width:")
    MyGui.Add("Edit", "w100 vOffsetW", DefaultW)

    MyGui.Add("Text", , "Offset height:")
    MyGui.Add("Edit", "w100 vOffsetH", DefaultH)

    ; -------------------------------
    ; Keybind settings
    ; -------------------------------
    MyGui.Add("Text", , "Cascade hotkey:")
    MyGui.Add("Edit", "w180 vCascadeHotkey", CascadeHotkey)

    MyGui.Add("Text", , "Open settings hotkey:")
    MyGui.Add("Edit", "w180 vGuiHotkey", GuiHotkey)

    chk := MyGui.Add("Checkbox", "vResize", "Resize")
    chk.Value := Resize

    btnSave := MyGui.Add("Button", "Default", "Save")
    btnUpdate := MyGui.Add("Button", "x+10", "Update")
    btnRegister := MyGui.Add("Button", "x+10", "Register Window Size")
    btnHelp := MyGui.Add("Button", "x+10", "Help")

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
    helpText :="Modifier keys must be placed at the beginning: ^!+# (Ctrl/Alt/Shift/Win)`n(Example Ctrl+Alt+F9 = ^!F9)`nRegister Size saves the size of the current front window."

    MsgBox helpText, "Settings Help", "Iconi"
}

LoadOffsetToGui(ctrl, *)
{
    MyGui := ctrl.Gui
    global OffsetConfig, DefaultW, DefaultH, ConfigFile, DefaultSection

    exe := MyGui["AppChoice"].Text

    if OffsetConfig.Has(exe)
    {
        ; Registered application
        MyGui["OffsetW"].Text := OffsetConfig[exe].w
        MyGui["OffsetH"].Text := OffsetConfig[exe].h
    }
    else
    {
        ; Unregistered application -> read Unregistered from INI
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
        MsgBox "Offset width or height is not a number."
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
        MsgBox "Cascade and GUI cannot use the same hotkey."
        return false
    }

    ; Validate hotkeys
    if !ValidateHotkeyPair(newCascadeHotkey, newGuiHotkey)
        return false

    ; Save offset
    OffsetConfig[exe] := { w: w, h: h }

    IniWrite(w, ConfigFile, exe, "Width")
    IniWrite(h, ConfigFile, exe, "Height")

    ; Save resize option
    Resize := MyGui["Resize"].Value
    IniWrite(Resize ? 1 : 0, ConfigFile, "Options", "Resize")

    ; Save keybinds
    CascadeHotkey := newCascadeHotkey
    GuiHotkey := newGuiHotkey

    IniWrite(CascadeHotkey, ConfigFile, "Keybind", "Cascade")
    IniWrite(GuiHotkey, ConfigFile, "Keybind", "Gui")

    RegisterHotkeys()

    return true
}

; ===============================
; Keybind
; ===============================
RegisterHotkeys()
{
    global CascadeHotkey, GuiHotkey
    global RegisteredCascadeHotkey, RegisteredGuiHotkey

    ; Disable existing hotkeys
    if (RegisteredCascadeHotkey != "")
        try Hotkey(RegisteredCascadeHotkey, "Off")

    if (RegisteredGuiHotkey != "")
        try Hotkey(RegisteredGuiHotkey, "Off")

    ; Prevent duplicates
    if (CascadeHotkey = GuiHotkey)
    {
        MsgBox "Cascade and GUI had the same hotkey. Resetting to default (F9/F10)."
        CascadeHotkey := "F9"
        GuiHotkey := "F10"

        IniWrite(CascadeHotkey, ConfigFile, "Keybind", "Cascade")
        IniWrite(GuiHotkey, ConfigFile, "Keybind", "Gui")
    }

    ; Register cascade hotkey
    try
    {
        Hotkey(CascadeHotkey, CascadeWindows, "On")
        RegisteredCascadeHotkey := CascadeHotkey
    }
    catch
    {
        MsgBox "Invalid cascade hotkey. Using default F9.`n`nValue: " CascadeHotkey
        CascadeHotkey := "F9"
        IniWrite(CascadeHotkey, ConfigFile, "Keybind", "Cascade")
        Hotkey(CascadeHotkey, CascadeWindows, "On")
        RegisteredCascadeHotkey := CascadeHotkey
    }

    ; Register GUI hotkey
    try
    {
        Hotkey(GuiHotkey, ShowConfigGui, "On")
        RegisteredGuiHotkey := GuiHotkey
    }
    catch
    {
        MsgBox "Invalid GUI hotkey. Using default F10.`n`nValue: " GuiHotkey
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
        MsgBox "Cascade and GUI cannot use the same hotkey."
        return false
    }

    try
    {
        Hotkey(testCascade, TempHotkeyHandler, "On")
        Hotkey(testCascade, "Off")
    }
    catch
    {
        MsgBox "Invalid cascade hotkey:`n" testCascade
        return false
    }

    try
    {
        Hotkey(testGui, TempHotkeyHandler, "On")
        Hotkey(testGui, "Off")
    }
    catch
    {
        MsgBox "Invalid GUI hotkey:`n" testGui
        return false
    }

    return true
}

TempHotkeyHandler(*)
{
    ; dummy for validation
}

; ===============================
; Register size
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
    global Resize
    global CascadeHotkey, GuiHotkey

    ; Create ini if missing
    if !FileExist(ConfigFile)
    {
        IniWrite(DefaultW, ConfigFile, DefaultSection, "Width")
        IniWrite(DefaultH, ConfigFile, DefaultSection, "Height")
        IniWrite("F9", ConfigFile, "Keybind", "Cascade")
        IniWrite("F10", ConfigFile, "Keybind", "Gui")
        IniWrite(0, ConfigFile, "Options", "Resize")
    }

    ; Load defaults
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
