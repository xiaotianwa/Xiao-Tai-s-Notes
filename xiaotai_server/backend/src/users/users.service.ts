import {
  ConflictException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import { Prisma, User } from "@prisma/client";
import * as bcrypt from "bcryptjs";

import { PrismaService } from "../common/prisma/prisma.service";
import type { AuthUser } from "../auth/auth-user";

@Injectable()
export class UsersService {
  constructor(private readonly prisma: PrismaService) {}

  async findByUsername(username: string): Promise<User | null> {
    return this.prisma.user.findUnique({ where: { username } });
  }

  async findById(id: string): Promise<User | null> {
    return this.prisma.user.findUnique({ where: { id } });
  }

  async getAuthUserById(id: string): Promise<AuthUser> {
    const user = await this.findById(id);
    if (!user || user.status !== "active") {
      throw new NotFoundException("用户不存在或已停用");
    }
    return this.toAuthUser(user);
  }

  async createAdminIfMissing(input: {
    username: string;
    password: string;
    nickname: string;
  }): Promise<AuthUser> {
    const existing = await this.findByUsername(input.username);
    if (existing) {
      if (existing.role !== "admin") {
        throw new ConflictException("初始化账号已存在但不是管理员");
      }
      return this.toAuthUser(existing);
    }

    const passwordHash = await bcrypt.hash(input.password, 12);
    const user = await this.prisma.user.create({
      data: {
        username: input.username,
        nickname: input.nickname,
        role: "admin",
        passwordHash,
      },
    });
    return this.toAuthUser(user);
  }

  toAuthUser(user: User): AuthUser {
    return {
      id: user.id,
      username: user.username,
      nickname: user.nickname,
      role: user.role,
      status: user.status,
    };
  }

  selectPublicUser(): Prisma.UserSelect {
    return {
      id: true,
      username: true,
      nickname: true,
      role: true,
      status: true,
      createdAt: true,
      updatedAt: true,
    };
  }
}
