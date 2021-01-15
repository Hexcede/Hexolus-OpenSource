# Anticheat
The anticheat is designed to stop most common movement exploits from the server alone with no help from the client.
It's designed with a methodology focusing solely on prevention of exploits vs disincentive for using them.

It consistently prevents noclipping, speed exploits, teleportation, and more to come with little detrement to the player.

# Caveats
Unfortunately, the exploit has some limitations around how physics may work on a player that may or may not be detremental to your game.
Here is a list of currently unsupported behaviours:
1. Boosting/flinging. This is the case due to the anticheat's speed checks. I would recommend disabling speed checks if you intend to boost/fling the player. This will be addressed in the future. (The fix in partial thanks to grilme99)
2. Vehicle seats. Vehicle seat compatibility is still being tested, the intended behavior is that checks become disabled when the player sits in a seat, but, there might be something I've missed.

# Teleportation
In order to teleport players, you must take server ownership of them for at least one frame:
```lua
coroutine.wrap(function()
	rootPart:SetNetworkOwner(nil)
	rootPart.CFrame = cframe
	RunService.Heartbeat:Wait()
	rootPart:SetNetworkOnwer(player)
end)()
```
