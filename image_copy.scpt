#!/usr/bin/osascript
on run argv
  set currentDir to do shell script "pwd"
  set the clipboard to (read POSIX file (POSIX path of (first item of argv)) as JPEG picture)
end run