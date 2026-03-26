#!/bin/bash
osascript << 'EOF'
tell application "System Events"
    set frontApp to name of first application process whose frontmost is true
end tell
tell application "iTerm" to activate
delay 0.08
tell application "System Events" to key code 36
if frontApp is not "iTerm2" and frontApp is not "iTerm" then
    tell application frontApp to activate
end if
EOF
