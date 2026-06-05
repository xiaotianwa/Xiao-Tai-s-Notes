const { PrismaClient } = require('@prisma/client');

const prisma = new PrismaClient();

async function main() {
  console.log('开始创建公告表...');
  
  try {
    // 创建公告表
    await prisma.$executeRawUnsafe(`
      CREATE TABLE IF NOT EXISTS "announcements" (
        "id" TEXT NOT NULL PRIMARY KEY,
        "title" TEXT NOT NULL,
        "content" TEXT NOT NULL,
        "type" TEXT NOT NULL DEFAULT 'info',
        "priority" INTEGER NOT NULL DEFAULT 0,
        "target_users" TEXT,
        "start_at" DATETIME,
        "end_at" DATETIME,
        "enabled" BOOLEAN NOT NULL DEFAULT true,
        "created_by" TEXT NOT NULL,
        "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        "updated_at" DATETIME NOT NULL
      )
    `);
    console.log('✓ 公告表创建成功');

    // 创建索引
    await prisma.$executeRawUnsafe(`
      CREATE INDEX IF NOT EXISTS "announcements_enabled_start_at_end_at_idx" 
      ON "announcements"("enabled", "start_at", "end_at")
    `);
    console.log('✓ 索引 1 创建成功');

    await prisma.$executeRawUnsafe(`
      CREATE INDEX IF NOT EXISTS "announcements_priority_idx" 
      ON "announcements"("priority")
    `);
    console.log('✓ 索引 2 创建成功');

    await prisma.$executeRawUnsafe(`
      CREATE INDEX IF NOT EXISTS "announcements_created_at_idx" 
      ON "announcements"("created_at")
    `);
    console.log('✓ 索引 3 创建成功');

    console.log('\n✅ 公告表和索引创建完成！');
  } catch (error) {
    console.error('❌ 创建失败:', error.message);
    process.exit(1);
  } finally {
    await prisma.$disconnect();
  }
}

main();
