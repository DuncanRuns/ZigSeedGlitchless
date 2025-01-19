package xyz.duncanruns.zsg.bastionchecker;

import Xinyuiii.enumType.BastionType;
import Xinyuiii.properties.BastionGenerator;
import com.seedfinding.mccore.util.block.BlockDirection;
import com.seedfinding.mccore.util.block.BlockRotation;
import com.seedfinding.mccore.util.pos.BPos;
import com.seedfinding.mccore.util.pos.CPos;
import com.seedfinding.mccore.version.MCVersion;
import com.seedfinding.mcfeature.loot.item.ItemStack;

import java.io.IOException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.function.Predicate;

public class ZSGBastionCheckerTest {
    private static final Map<BastionType, Predicate<ChestInfo>> TYPE_TO_VALID_CHEST_CHECKER = new HashMap<>();

    static {
        TYPE_TO_VALID_CHEST_CHECKER.put(BastionType.TREASURE, c -> c.y == 82);
        TYPE_TO_VALID_CHEST_CHECKER.put(BastionType.BRIDGE, c -> true);
        TYPE_TO_VALID_CHEST_CHECKER.put(BastionType.STABLES, c -> c.y == 35 || c.y == 58 || c.y == 72);
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

    private static double percentOf(double x, double total) {
        return 100 * x / total;
    }

    public static void main(String[] args) throws IOException {
        BastionGenerator bastionGenerator = new BastionGenerator(MCVersion.v1_16_1);
        ChestInfo chestInfo = new ChestInfo();
        Map<BastionType, List<Integer>> data = new HashMap<>();
        for (BastionType bastionType : BastionType.values()) data.put(bastionType, new ArrayList<>());
        int totalCheckedSeeds = 100000;
        for (long seed = 0; seed < totalCheckedSeeds; seed++) {
            byte b1 = 0;
            byte b2 = 0;
            CPos bastionPos = new CPos(b1, b2);
            if (!bastionGenerator.generate(seed, bastionPos)) {
                System.out.write(new byte[]{-1});
                return;
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
            ).sum();
            if (obsidian > Byte.MAX_VALUE) obsidian = Byte.MAX_VALUE;

            data.get(bastionType).add(obsidian);
        }


//        long oldTotal = data.values().stream().mapToLong(integers -> integers.stream().mapToInt(Integer::intValue).filter(i -> i > 17).count()).sum();
        long newTotal = data.entrySet().stream().mapToLong(e -> e.getValue().stream().mapToInt(Integer::intValue).filter(i -> i + getExpectedTradedObsidian(e.getKey()) > 19).count()).sum();

        for (BastionType bastionType : BastionType.values()) {
            System.out.println(bastionType);
            int expectedTradedObsidian = getExpectedTradedObsidian(bastionType);
            List<Integer> raw = data.get(bastionType);
            long oldCount = raw.stream().mapToInt(Integer::intValue).filter(i -> i >= 18).count();
//            System.out.println(String.format(">=18 in relevant chests: %d (%.2f", oldCount, percentOf(oldCount, oldTotal)) + "%)");
            long newCount = raw.stream().mapToInt(i -> expectedTradedObsidian + i).filter(i -> i >= 20).count();
            System.out.println(String.format("%d (%.2f", newCount, percentOf(newCount, newTotal)) + "% of good bastions)");
//            System.out.println();
        }

        System.out.println("ALL");
//        System.out.println(String.format(">=18 in relevant chests: %d (%.2f", oldTotal, percentOf(oldTotal, totalCheckedSeeds)) + "%)");
        System.out.println(String.format("%d (%.2f", newTotal, percentOf(newTotal, totalCheckedSeeds)) + "% of all checked bastions)");

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
