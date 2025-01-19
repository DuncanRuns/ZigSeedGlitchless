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
import java.nio.ByteBuffer;
import java.util.HashMap;
import java.util.Map;
import java.util.function.Predicate;

public class ZSGBastionChecker {
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

    public static void main(String[] args) throws IOException {
        // Send successful start bytes
        System.out.write(new byte[]{-1, -1, -1, -1, -1, -1, -1, -1, 0, 0, 0, 0, 0, 0, 0, 0});
        System.out.flush();

        BastionGenerator bastionGenerator = new BastionGenerator(MCVersion.v1_16_1);
        ChestInfo chestInfo = new ChestInfo();
        while (true) {
            byte[] buf = new byte[8];
            if (System.in.read(buf, 0, 8) < 8) return;
            long seed = ByteBuffer.wrap(buf).getLong();
            if (System.in.read(buf, 0, 2) < 2) return;
            byte b1 = buf[0];
            byte b2 = buf[1];
            CPos bastionPos = new CPos(b1, b2);
            if (!bastionGenerator.generate(seed, bastionPos)) {
                System.out.write(new byte[]{-1});
                continue;
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
            obsidian += obsidian + getExpectedTradedObsidian(bastionType);

            byte[] bytes = {obsidian > Byte.MAX_VALUE ? Byte.MAX_VALUE : (byte) obsidian};
            System.out.write(bytes);
            System.out.flush();
        }
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
