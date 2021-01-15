# Anticheat
The anticheat is designed to stop most common movement exploits from the server alone with no help from the client.
It's designed with a methodology focusing solely on prevention of exploits vs disincentive for using them.

It consistently prevents noclipping, speed exploits, teleportation, and more to come with little detrement to the player.
The settings have already been tuned to fairly optimal values, so, you shouldn't need to do much.

# Implementing it into your game
Implementing this into your game is pretty simple, but some components in your game might not behave as you expect them to. You should do thorough testing, especially if your game uses any sort of physics stuff involving the player, such as boosting them by setting Velocity. This in particular will be addressed fairly soon.

To use the anticheat, just require the module and call the starter function:
```lua
local Anticheat = require(script:WaitForChild("Anticheat"))()
```

Generally, it won't be necessary to access any of the Anticheat's methods, and I recommend that if you want to make behaviour changes that you do so directly, and marking where you've made changes.

# Caveats
Unfortunately, the antiexploit has some limitations around how physics may work on a player that may or may not be detremental to your game.
Here is a list of currently unsupported behaviours:
1. Boosting/flinging. This is the case due to the anticheat's speed checks. I would recommend disabling speed checks if you intend to boost/fling the player. This will be addressed in the future. (The fix in partial thanks to grilme99)
2. Vehicle seats. Vehicle seat compatibility is still being tested, the intended behavior is that checks become disabled when the player sits in a seat, but, there might be something I've missed.
3. BodyMovers. BodyMovers are completely incompatible with the anticheat. Some may work, but most will not. If you need to 
