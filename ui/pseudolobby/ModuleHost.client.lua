-- ReplicatedStorage/PseudoLobbyClient/<Controller> (LocalScript template): hosts one of the hub's lobby controllers for the
-- after-match lobby. PseudoLobbyRunner clones this (with its Module child) into PlayerScripts on each show, so the module
-- is required fresh against the new map copy, and destroying the clone on hide disconnects everything it hooked.
local m = require(script:WaitForChild("Module"))
if type(m) == "table" and type(m.Start) == "function" then m.Start() end
