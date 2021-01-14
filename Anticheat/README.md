# Anticheat
The anticheat is designed to stop most common movement exploits from the server alone with no help from the client.
It's designed with a methodology focusing solely on prevention of exploits vs disincentive for using them.

It consistently prevents noclipping, speed exploits, teleportation, and more to come with little detrement to the player.

# Caveats
Unfortunately, the exploit has some limitations around how physics may work on a player that may or may not be detremental to your game.
Here is a list of currently unsupported behaviours:
1. Teleporting players. This will be resolved in the future in an official way, the solution right now is to update players' InitialCFrame data to match the location you are teleporting them to, which will require a little bit of your own code
2. Boosting/flinging. This is the case due to the anticheat's speed checks. I would recommend disabling speed checks if you intend to boost/fling the player.
3. Static animations. Due to the teleportation check, you can't move players without updating their Velocity to allow for it. If this distance is too great, you'll trigger speed checks and thus need to disable them.
4. Vehicle seats. This is being resolved shortly.
