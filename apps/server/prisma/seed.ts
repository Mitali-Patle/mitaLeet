import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  console.log('[Seed] Starting...');

  // Create demo users
  const users = await Promise.all(
    ['akshay', 'priya', 'mitali', 'rahul', 'sneha'].map(async (name) => {
      return prisma.user.upsert({
        where: { googleId: `google-${name}` },
        update: {},
        create: {
          email: `${name}@example.com`,
          displayName: name,
          googleId: `google-${name}`,
          status: 'OFFLINE',
          profile: {
            create: {
              username: name,
              xp: Math.floor(Math.random() * 3000),
              totalSolves: Math.floor(Math.random() * 150),
              easySolves: Math.floor(Math.random() * 60),
              mediumSolves: Math.floor(Math.random() * 50),
              hardSolves: Math.floor(Math.random() * 20),
            },
          },
          streak: {
            create: {
              currentStreak: Math.floor(Math.random() * 15),
              longestStreak: Math.floor(Math.random() * 30),
            },
          },
        },
      });
    }),
  );

  console.log(`[Seed] Created ${users.length} users`);

  // Create demo group
  const group = await prisma.group.upsert({
    where: { code: 'DSA-X7K2' },
    update: {},
    create: {
      name: 'DSA Grinders',
      code: 'DSA-X7K2',
      description: 'Daily DSA practice squad',
      members: {
        create: users.map((u, i) => ({
          userId: u.id,
          role: i === 0 ? 'OWNER' : 'MEMBER',
        })),
      },
    },
  });

  console.log(`[Seed] Created group: ${group.name}`);
  console.log('[Seed] Done.');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
