--!strict
-- Shared/Config/AnimationIds.lua  (docs/08_rigs_and_animation.md §1.2)
--
-- Default Roblox R15 animation ids for NPC humans. NOT typed from memory: read on 2026-10-09 in play mode
-- from the live player's Animate script (Animate.<group>.<Animation>.AnimationId) of the Elias
-- StarterCharacter, Studio 0.742. Re-read them the same way if Roblox ever changes the defaults.

return {
	Idle = "http://www.roblox.com/asset/?id=507766388", -- idle.Animation1
	IdleLook = "http://www.roblox.com/asset/?id=507766666", -- idle.Animation2
	Walk = "http://www.roblox.com/asset/?id=913402848", -- walk.WalkAnim
	Run = "http://www.roblox.com/asset/?id=913376220", -- run.RunAnim
	Jump = "http://www.roblox.com/asset/?id=507765000", -- jump.JumpAnim
	Fall = "http://www.roblox.com/asset/?id=507767968", -- fall.FallAnim
	Climb = "http://www.roblox.com/asset/?id=507765644", -- climb.ClimbAnim
	Sit = "http://www.roblox.com/asset/?id=2506281703", -- sit.SitAnim
}
