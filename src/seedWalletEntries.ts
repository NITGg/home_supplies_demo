import { prisma } from "@/config/prisma";
import { logger } from "@/config/logger";

async function main() {
  logger.info("Starting to seed baseline WalletEntry records...");

  // Find all wallets that have a non-zero balance
  const wallets = await prisma.wallet.findMany({
    where: {
      balance: { not: 0 },
    },
    select: {
      id: true,
      balance: true,
      walletEntries: {
        take: 1, // just check if any exist
      },
    },
  });

  let createdCount = 0;

  for (const wallet of wallets) {
    // Only create a baseline entry if the wallet has no existing entries
    if (wallet.walletEntries.length === 0) {
      await prisma.walletEntry.create({
        data: {
          wallet_id: wallet.id,
          amount: wallet.balance,
          created_at: new Date(), // They will be stamped with "today"
        },
      });
      createdCount++;
    }
  }

  logger.info(`Baseline seed complete. Created ${createdCount} WalletEntry records.`);
}

main()
  .catch((e) => {
    logger.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
