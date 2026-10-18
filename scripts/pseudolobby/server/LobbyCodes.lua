-- [PSEUDOLOBBY] copied from the hub (2026-10-18) for the match places' after-match lobby; changes are tagged [PSEUDOLOBBY].
-- ServerScriptService/Lobby/LobbyCodes (ModuleScript)
-- Redeemable codes. Kept on the server so players can't read the list from the client.
-- Codes are case-insensitive (typed codes are upper-cased). Each player can redeem a code once.
--   Credits = number of Credits to give
--   Items   = item ids from LobbyConfig.Items to unlock (optional)
--   Expires = os.time() after which the code stops working (optional), e.g. os.time({year=2026,month=12,day=31})
return {
	TACTICALS = { Credits = 500 },
	RELEASE = { Credits = 250, Items = { "Knife" } },
	-- TESTCODE = { Credits = 100, Expires = os.time({ year = 2026, month = 1, day = 1 }) },
}
