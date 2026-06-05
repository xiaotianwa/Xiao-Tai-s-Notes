import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcryptjs';

import { PrismaService } from '../common/prisma/prisma.service';
import type { AppConfig } from '../config/configuration';
import type { AuthUser, JwtPayload } from './auth-user';

@Injectable()
export class RefreshTokenService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService<AppConfig, true>,
  ) {}

  async create(user: AuthUser): Promise<string> {
    const expiresIn = this.configService.get('jwtRefreshExpiresIn', {
      infer: true,
    });
    const secret = this.configService.get('jwtRefreshSecret', { infer: true });
    const payload: JwtPayload = {
      sub: user.id,
      username: user.username,
      role: user.role,
    };
    const refreshToken = await this.jwtService.signAsync(payload, {
      secret,
      expiresIn,
    });
    const tokenHash = await bcrypt.hash(refreshToken, 12);
    const expiresAt = new Date(Date.now() + parseDurationMs(expiresIn));
    await this.prisma.refreshToken.create({
      data: {
        userId: user.id,
        tokenHash,
        expiresAt,
      },
    });
    return refreshToken;
  }

  async verifyAndRotate(refreshToken: string): Promise<string> {
    const secret = this.configService.get('jwtRefreshSecret', { infer: true });
    let payload: JwtPayload;
    try {
      payload = await this.jwtService.verifyAsync<JwtPayload>(refreshToken, {
        secret,
      });
    } catch {
      throw new UnauthorizedException('刷新令牌无效或已过期');
    }

    const storedTokens = await this.prisma.refreshToken.findMany({
      where: {
        userId: payload.sub,
        revokedAt: null,
        expiresAt: { gt: new Date() },
      },
      orderBy: { createdAt: 'desc' },
      take: 10,
    });

    for (const storedToken of storedTokens) {
      const matched = await bcrypt.compare(refreshToken, storedToken.tokenHash);
      if (!matched) {
        continue;
      }
      await this.prisma.refreshToken.update({
        where: { id: storedToken.id },
        data: { revokedAt: new Date() },
      });
      return payload.sub;
    }

    throw new UnauthorizedException('刷新令牌已失效');
  }

  async revoke(refreshToken: string): Promise<void> {
    const secret = this.configService.get('jwtRefreshSecret', { infer: true });
    let payload: JwtPayload;
    try {
      payload = await this.jwtService.verifyAsync<JwtPayload>(refreshToken, {
        secret,
      });
    } catch {
      return;
    }

    const storedTokens = await this.prisma.refreshToken.findMany({
      where: {
        userId: payload.sub,
        revokedAt: null,
      },
    });

    for (const storedToken of storedTokens) {
      const matched = await bcrypt.compare(refreshToken, storedToken.tokenHash);
      if (!matched) {
        continue;
      }
      await this.prisma.refreshToken.update({
        where: { id: storedToken.id },
        data: { revokedAt: new Date() },
      });
      return;
    }
  }
}

function parseDurationMs(value: string): number {
  const match = /^(\d+)([smhd])$/.exec(value);
  if (!match) {
    throw new Error(`Unsupported duration format: ${value}`);
  }
  const amount = Number(match[1]);
  const unit = match[2];
  switch (unit) {
    case 's':
      return amount * 1000;
    case 'm':
      return amount * 60 * 1000;
    case 'h':
      return amount * 60 * 60 * 1000;
    case 'd':
      return amount * 24 * 60 * 60 * 1000;
    default:
      throw new Error(`Unsupported duration unit: ${unit}`);
  }
}
