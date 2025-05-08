# ZigSeedGlitchless

Releases and some source code for ZigSeedGlitchless

(You should go to releases)

## Filters

### 1.16 Nether (for all 1.16 filters)

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

### 1.16 Mapless

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

### 1.16 Shipwreck

-   Shipwreck in ++ region.
    -   Only full upright shipwrecks (for guaranteed wood access).
    -   Flint and steel craftable.
    -   Pickaxe craftable (diamond or iron).
    -   Bucket craftable.
    -   5 carrots or 10 bread, or a combination.
-   Spawnpoint within 48 blocks of shipwreck.
-   Ravine within 80 blocks of shipwreck (50 for OP version).

### 1.16 Village

-   Village in ++ region.
    -   Non-abandoned, plains/savanna/desert only.
    -   Nothing else guaranteed in village. Get lucky or do cod strats.
-   Ruined portal within 48 blocks of village center.
    -   Surface ruined portals with lava only.
-   Spawnpoint within 32 blocks of village or ruined portal.

### 1.16 Temple

-   Desert pyramid in ++ region.
    -   Flint and steel craftable.
    -   Pickaxe craftable (diamond or iron).
    -   Bucket craftable.
-   Ruined portal within 64 blocks of pyramid.
    -   Surface ruined portals with lava only.
-   Spawnpoint within 32 blocks of pyramid or ruined portal.
-   Ravine within 80 blocks of pyramid (50 for OP version).

### 1.15 Insomniac (not on leaderboard and it's kinda shit)

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

1. 1.16 Mapless
2. 1.16 Mapless (OP)
3. 1.15 Insomniac
4. 1.16 Village
5. 1.16 Village (OP)
6. 1.16 Temple
7. 1.16 Temple (OP)
8. 1.16 Shipwreck
9. 1.16 Shipwreck (OP)

Can be set in `config.json`.

## Source Code

Some portions of the source are released here. The token generation and other aspects of ZigSeedGlitchless will remain closed source.

Any source code found in the src directory or the ZSGJavaBits directory in this repository falls under MIT licensing, but the ZigSeedGlitchless source code that is **not** found here remains as ARR. Additionally, the released executables in "Releases" also fall under ARR.
