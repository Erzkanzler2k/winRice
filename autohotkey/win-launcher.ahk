#Requires AutoHotkey v2.0
#SingleInstance Force
; winRice owns the Win key, so the native Start menu never opens:
; a bare Win tap opens the launcher, and the few Win combos below are
; re-implemented because Windows no longer sees the key.
#UseHook

LWin::Send "!{Space}"
#e::Run "explorer.exe shell:MyComputerFolder"
#d::ComObject("Shell.Application").ToggleDesktop
#l::Run "rundll32.exe user32.dll,LockWorkStation"
#s::Send "!{Space}"
