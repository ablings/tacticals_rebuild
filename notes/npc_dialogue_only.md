# No panel prompts: dialogue-only NPCs, counter / gun wall / dais prompts hidden (2026-10-16)

Edward: "no shop or anything is going to be made, so just remove that mechanic for now" (the Outfitter and Armory NPCs), then
he approved removing the counter, gun-wall and dais prompts too. Only in `Tacticals_rebuild.rbxl` (studio 8ef4e21a). Not saved.

| What | Path |
|---|---|
| Script (idempotent, UNDO flag) | `fix/no_panel_prompts.lua` -> `python tools/run_luau.py fix/no_panel_prompts.lua [UNDO]` (first written as `fix/npc_dialogue_only.lua`, renamed) |
| Source backup | `ServerStorage._RebuildRemoved.NPC_LobbyUIController_Orig` (clone of the controller before the edit) |

## What changed
1. **One game script edited**: `StarterPlayer.StarterPlayerScripts.Client.Controllers.LobbyUIController` (ModuleScript), the world-prompt
   handler (`ProximityPromptService.PromptTriggered`, around line 1415). The `OpenPanel` test now also needs
   `prompt:GetAttribute("NPC_OpensPanel") ~= false`, with the marker comment on its own line:
   ```lua
   -- [NPC] dialogue-only (Edward 2026-10-16): a prompt with NPC_OpensPanel = false keeps its talk lines but opens no panel
   if id and id ~= "" and prompt:GetAttribute("NPC_OpensPanel") ~= false then
   ```
   A prompt without the attribute behaves as before. No other script was changed: `LobbyLabels` (speech bubbles from `TalkLines`)
   does not read the flag, so the NPCs still talk.
2. **NPC prompts** `NPCs.NPC_Quartermaster` (OUTFITTER, `OpenPanel=Kit`) and `NPCs.NPC_Supply` (SUPPLY, `OpenPanel=Shop`):
   attribute `NPC_OpensPanel = false`. `OpenPanel`, `TalkLines`, ActionText "Talk" are unchanged, so the prompt still shows "Talk".
3. **Interact prompts hidden** (`Enabled = false`, original in attribute `NoPanel_Orig`, plus `NPC_OpensPanel = false`):
   `Interact.Shop_Counter` (still holds `OpenPanel=Shop`, "Browse outfits / CHECKOUT"), `Interact.GunWall_Kit` (`OpenPanel=Kit`,
   "Customise KIT"), `Interact.Armory_Dais` (`OpenPanel=Kit`, "Customise KIT"). Their `OpenPanel` attributes stay, so UNDO (or setting
   Enabled back) restores the panels. The Shop / Kit panel UI code and the Showroom are untouched.
4. `NPC_DuelsOfficer` (`OpenPanel=Play`) is untouched and still opens the PLAY panel. **No light or RoomFX change.**

To bring one prompt back: set its `NPC_OpensPanel` to true (or remove it) and, for an Interact prompt, `Enabled = true`.

## Checks
- Idempotent (second run: "already patched"); UNDO round trip (twice): the marked line reverted in place, attributes cleared, the
  three prompts Enabled again; re-applied.
- **Play** (play lock taken / released): the three Interact prompts are `Enabled=false` on the client; standing at the counter (5.7
  studs, range 9), the dais (~3.6, range 11) and the gun wall (6.5, range 12) **no prompt was shown** (PromptShown listener). Both NPC
  prompts were shown ("Talk") at 3.3-3.6 studs. `NPC_DuelsOfficer` keeps no flag.
- **Not verified in Play: the E press itself.** With the Studio window unfocused (no computer use allowed while Edward is at the PC),
  neither the MCP keyboard tool nor `InputHoldBegin/End` fired `PromptTriggered` (not even a plain Triggered on the prompt), so the
  speech bubble / no-panel result could not be observed. By code: the NPC path still reaches `LobbyLabels` (unchanged, no flag check)
  and the controller line skips `LobbyUI.Open` for flagged prompts. **One E press at each NPC by Edward (or a focused session) closes this.**
- check_hub1 / check_rooms2 (FAILS 0) / check_rooms3 (FAILS 0) / check_training ALL OK; console in Play = baseline.

## For the UI session (hand-over)
The only script changed is `Client.Controllers.LobbyUIController` (one condition + one comment line in the world-prompt handler).
If the UI session edits that ModuleScript, keep the marked line or re-run `fix/no_panel_prompts.lua` (it re-patches only if the
marker is missing). UNDO reverts just the marked line in place, so other sessions' later edits survive; the full backup is used only
if the marked line was edited by hand.
