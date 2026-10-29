# source me. setpose <gun|""> "Clip:t,Clip:t" [rootLuaCFrame]
setpose() { { echo "--@lib"; if [ -n "$1" ]; then echo "GUN = \"$1\""; else echo "GUN = nil"; fi; echo "ROOT = ${3:-nil}"; echo "LIST = {"; echo "$2" | tr ',' '\n' | awk -F: '{printf "{\"%s\", %s},\n",$1,$2}'; echo "}"; tail -n +2 lua/setpose.lua; } > lua/_sp.lua; sh run.sh lua/_sp.lua >/dev/null; }
