import * as dotenv from 'dotenv';
dotenv.config();

import { PrismaClient } from '@prisma/client';
import * as bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

async function main(): Promise<void> {
  const username = process.env.ADMIN_INIT_USERNAME ?? 'admin';
  const password = process.env.ADMIN_INIT_PASSWORD;
  const nickname = process.env.ADMIN_INIT_NICKNAME ?? '小泰管理员';

  if (!password || password.length < 8) {
    throw new Error('ADMIN_INIT_PASSWORD is required and must be at least 8 characters');
  }

  const existing = await prisma.user.findUnique({ where: { username } });
  if (existing) {
    console.log(`Admin already exists: ${username}`);
    return;
  }

  const passwordHash = await bcrypt.hash(password, 12);
  const user = await prisma.user.create({
    data: {
      username,
      nickname,
      role: 'admin',
      passwordHash,
    },
  });
  console.log(`Admin created: ${user.username} (${user.id})`);
}

main()
  .catch((error: unknown) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
