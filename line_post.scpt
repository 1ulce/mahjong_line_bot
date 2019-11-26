#!/usr/bin/osascript
on run argv
   tell application "LINE"
      activate
      delay 1
      tell applications "System Events"
         keystroke (item 1 of argv)
         keystroke return
      end tell
   end tell
end run