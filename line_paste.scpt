#!/usr/bin/osascript
on run argv
   tell application "LINE"
      activate
      delay 1
      tell applications "System Events"
         keystroke "v" using {command down}
         keystroke return
      end tell
   end tell
end run