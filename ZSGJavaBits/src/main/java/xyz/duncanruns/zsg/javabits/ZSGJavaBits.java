package xyz.duncanruns.zsg.javabits;

import Xinyuiii.enumType.BastionType;
import Xinyuiii.properties.BastionGenerator;
import com.seedfinding.mcbiome.source.BiomeSource;
import com.seedfinding.mccore.block.Block;
import com.seedfinding.mccore.block.Blocks;
import com.seedfinding.mccore.state.Dimension;
import com.seedfinding.mccore.util.block.BlockDirection;
import com.seedfinding.mccore.util.block.BlockRotation;
import com.seedfinding.mccore.util.pos.BPos;
import com.seedfinding.mccore.util.pos.CPos;
import com.seedfinding.mccore.version.MCVersion;
import com.seedfinding.mcfeature.loot.item.ItemStack;
import com.seedfinding.mcterrain.TerrainGenerator;

import java.io.IOException;
import java.nio.ByteBuffer;
import java.util.*;
import java.util.function.Predicate;

public class ZSGJavaBits {
    private static final Map<BastionType, Predicate<ChestInfo>> TYPE_TO_VALID_CHEST_CHECKER = new HashMap<>();
    private static final byte[] TRUE_BYTE_RESPONSE = {1};
    private static final byte[] FALSE_BYTE_RESPONSE = {0};
    private static final Set<Block> AIR_LIKE_BLOCKS = new HashSet<>(Arrays.asList(Blocks.AIR, Blocks.CAVE_AIR, Blocks.VOID_AIR));

    static {
        TYPE_TO_VALID_CHEST_CHECKER.put(BastionType.TREASURE, c -> c.y == 82);
        TYPE_TO_VALID_CHEST_CHECKER.put(BastionType.BRIDGE, c -> true);
        TYPE_TO_VALID_CHEST_CHECKER.put(BastionType.STABLES, c -> c.y == 35 || c.y == 72);
        TYPE_TO_VALID_CHEST_CHECKER.put(BastionType.HOUSING, c -> {
            if (c.y == 73) return true;
            if (c.y == 36) {
                BlockDirection towardsDoubleChest = c.bastionRotation.rotate(BlockDirection.SOUTH);
                BPos doubleChestPos = c.bastionOrigin.relative(towardsDoubleChest, 20).relative(towardsDoubleChest.getClockWise(), 6);
                if (c.pos.getX() == doubleChestPos.getX() && c.pos.getZ() == doubleChestPos.getZ()) return true;
                doubleChestPos = doubleChestPos.relative(towardsDoubleChest);
                return c.pos.getX() == doubleChestPos.getX() && c.pos.getZ() == doubleChestPos.getZ();
            }
            return false;
        });
    }

    public static void main(String[] args) throws IOException {
        // Send successful start bytes
        System.out.write(new byte[]{-1, -1, -1, -1, -1, -1, -1, -1, 0, 0, 0, 0, 0, 0, 0, 0});
        System.out.flush();

        BastionGenerator bastionGenerator = new BastionGenerator(MCVersion.v1_16_1);
        ChestInfo chestInfo = new ChestInfo();
        while (true) {
            byte[] buf = new byte[1];
            if (System.in.read(buf, 0, 1) < 1) return;
            byte b = buf[0];
            if (b == 0) { // Command 1: Get obsidian in bastion
                if (!respondBastionObsidian(bastionGenerator, chestInfo)) return;
            } else if (b == 1) { // Command 2: Check for terrain
                if (!respondCheckForTerrain()) return;
            }
        }
    }

    private static boolean respondCheckForTerrain() throws IOException {
        byte[] buf = new byte[8];
        if (System.in.read(buf, 0, 8) < 8) return false;
        long seed = ByteBuffer.wrap(buf).getLong();

        if (System.in.read(buf, 0, 4) < 4) return false;
        // The center of the bastion is offset in a random direction depending on the rotation, we won't worry about that.
        int bx = ((int) buf[0]) * 16;
        int bz = ((int) buf[1]) * 16;
        // The center of the crossroads starting piece is +11 +11 from -/- corner of the chunk.
        int fx = ((int) buf[2]) * 16 + 11;
        int fz = ((int) buf[3]) * 16 + 11;

        TerrainGenerator gen = TerrainGenerator.of(BiomeSource.of(Dimension.NETHER, MCVersion.v1_16_1, seed));

        boolean isHighFortTerrain = false;
        boolean isViable = (checkTerrainViability(gen, bx, bz, fx, fz, 60) ||
                (isHighFortTerrain = checkTerrainViability(gen, bx, bz, fx, fz, 95))
        ) && (checkTerrainViability(gen, 0, 0, bx, bz, 60) ||
                checkTerrainViability(gen, 0, 0, bx, bz, 95)
        );
        if (isViable && isHighFortTerrain) {
            int airCount = 0;
            for (int y = 95; y >= 50; y -= 5) {
                if (AIR_LIKE_BLOCKS.contains(gen.getBlockAt(fx, y, fz).orElse(Blocks.NETHERRACK))) {
                    airCount++;
                }
            }
            isViable = airCount >= 6;
        }

        System.out.write(isViable ? TRUE_BYTE_RESPONSE : FALSE_BYTE_RESPONSE);
        System.out.flush();

        return true;
    }

    private static boolean checkTerrainViability(TerrainGenerator gen, int x1, int z1, int x2, int z2, int y) {
        // Calculate distance and direction vector
        int dx = x2 - x1;
        int dz = z2 - z1;
        double distance = Math.sqrt(dx * dx + dz * dz);

        // Sample every 10 blocks
        int sampleInterval = 10;
        int numSamples = (int) (distance / sampleInterval) + 1;
        int airCount = 0;

        for (int i = 0; i < numSamples; i++) {
            double t = (double) i / (numSamples - 1);
            int x = (int) (x1 + dx * t);
            int z = (int) (z1 + dz * t);

            if (AIR_LIKE_BLOCKS.contains(gen.getBlockAt(x, y, z).orElse(Blocks.NETHERRACK))) {
                airCount++;
            }
        }

        return (double) airCount / numSamples >= 0.8;
    }

    private static boolean respondBastionObsidian(BastionGenerator bastionGenerator, ChestInfo chestInfo) throws IOException {
        byte[] buf = new byte[8];
        if (System.in.read(buf, 0, 8) < 8) return false;
        long seed = ByteBuffer.wrap(buf).getLong();
        if (System.in.read(buf, 0, 2) < 2) return false;
        byte b1 = buf[0];
        byte b2 = buf[1];
        CPos bastionPos = new CPos(b1, b2);
        if (!bastionGenerator.generate(seed, bastionPos)) {
            System.out.write(new byte[]{-1});
            System.out.flush();
            return true;
        }
        BastionType bastionType = bastionGenerator.getType();
        Predicate<ChestInfo> validChestChecker = TYPE_TO_VALID_CHEST_CHECKER.get(bastionType);
        chestInfo.bastionOrigin = bastionPos.toBlockPos();
        chestInfo.bastionRotation = bastionGenerator.getPieces().get(0).rotation;
        int obsidian = bastionGenerator.generateLoot().stream().filter(pair -> {
            chestInfo.pos = pair.getFirst();
            chestInfo.y = chestInfo.pos.getY();
            return validChestChecker.test(chestInfo);
        }).mapToInt(pair ->
                pair.getSecond().stream().filter(itemStack -> itemStack.getItem().getName().equals("obsidian")).mapToInt(ItemStack::getCount).sum()
        ).sum() + getExpectedTradedObsidian(bastionType);

        byte[] bytes = {obsidian > Byte.MAX_VALUE ? Byte.MAX_VALUE : (byte) obsidian};
        System.out.write(bytes);
        System.out.flush();
        return true;
    }

    private static int getExpectedTradedObsidian(BastionType type) {
        return type == BastionType.BRIDGE ? 7 : 4;
    }

    private static class ChestInfo {
        private BPos pos;
        private BlockRotation bastionRotation;
        private BPos bastionOrigin;
        private int y;
    }
}
