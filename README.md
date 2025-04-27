# ZigSeedGlitchless

Releases and some source code for ZigSeedGlitchless

(You should go to releases)

## Filters

### 1.16 Filter

-   BT within 10 chunks of 0,0.
    -   Flint and steel craftable.
    -   Pickaxe craftable (diamond or iron).
    -   Bucket craftable.
    -   Wood mineable (tnt w/ iron/gold pressure plate, or enough to craft iron/gold axe).
    -   Gravel mineable (any type of shovel craftable or another tnt available).
    -   OP version guarantees 2 TNT.
-   Spawnpoint within 32 blocks of bt (24 for OP version).
-   Forest within 10 blocks of bt.
    -   At least 400 blocks of forest within 20 blocks of the found forest.
-   Ravine within 80 blocks of bt (50 for OP version).
-   <=96 bastion (<=32 for OP version).
-   <=256 fortress from bastion (<=112 for OP version).
-   20 or more obsidian from 90% chance trades plus reasonable bastion chests.
    -   Slows down the filter; can be turned off in config (`"enable_bastion_checker": false,`).
    -   90% chance trades: 4+ obsidian in treasure/housing/stables, so 16 obsidian in chests required, 7+ obsidian in bridge, so 13 obsidian in chests required.
    -   Reasonable bastion chests: all bridge chests, only triple/bottom chest in stables, rampart chests in treasure, and triple/bottom double in housing
    -   These factors lead to the following distribution of bastions when running ZSG:
        -   37.5% Housing
        -   20.9% Stables
        -   14.5% Treasure
        -   27.1% Bridge
-   Terrain between 0,0 and bastion, and between bastion and fortress.
    -   Slows down the filter; off by default, can be turned on in config (`"enable_terrain_checker": true,`).
    -   Checks for 80% air in a straight line between 0,0 and bastion at y=60, or y=95 if y=60 fails.
    -   Checks for 80% air in a straight line between bastion and fortress at y=60, or y=95 if y=60 fails.
        -   If only y=95 is successful, also checks for 60% air between y=95 and y=50 at the starting piece of the fortress.

### 1.15 Filter (not on leaderboard and it's kinda shit)

-   Shipwreck in closest ++ region (0->128)
    -   diamond/iron tools craftable
    -   10+ emeralds and/or 7+ emeralds with flesh
    -   1+ tnt and/or 5+ gunpowder
-   Spawn within 30 blocks of ship
-   Monument +/+ from ship
-   Village +/+ from Monument
-   Fortress spawn within 60 blocks of village
-   Stronghold +/+ with distance <1600 from 0,0

### Filter IDS

1. Regular 1.16 Filter
2. OP 1.16 Filter
3. 1.15 Filter

## Source Code

Some portions of the source are released here. The token generation and other aspects of ZigSeedGlitchless will remain closed source.

Any source code found in the src directory or the BastionChecker directory in this repository falls under MIT licensing, but the ZigSeedGlitchless source code that is **not** found here remains as ARR. Additionally, the released executables in "Releases" also fall under ARR.
