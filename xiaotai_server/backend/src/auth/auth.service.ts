import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcryptjs';

import type { AppConfig } from '../config/configuration';
import { UsersService } from '../users/users.service';
import type { AuthUser, JwtPayload } from './auth-user';
import { RefreshTokenService } from './refresh-token.service';

export interface AuthTokens {
  accessToken: string;
  refreshToken: string;
  user: AuthUser;
}

@Injectable()
export class AuthService {
  constructor(
    private readonly usersService: UsersService,
    private readonly jwtService: JwtService,
    private readonly refreshTokenService: RefreshTokenService,
    private readonly configService: ConfigService<AppConfig, true>,
  ) {}

  async login(username: string, password: string): Promise<AuthTokens> {
    const user = await this.usersService.findByUsername(username);
    if (!user || user.status !== 'active') {
      throw new UnauthorizedException('账号或密码不正确');
    }

    const passwordMatched = await bcrypt.compare(password, user.passwordHash);
    if (!passwordMatched) {
      throw new UnauthorizedException('账号或密码不正确');
    }

    return this.issueTokens(this.usersService.toAuthUser(user));
  }

  async refresh(refreshToken: string): Promise<AuthTokens> {
    const userId = await this.refreshTokenService.verifyAndRotate(refreshToken);
    const user = await this.usersService.getAuthUserById(userId);
    return this.issueTokens(user);
  }

  async logout(refreshToken: string): Promise<{ loggedOut: true }> {
    await this.refreshTokenService.revoke(refreshToken);
    return { loggedOut: true };
  }

  private async issueTokens(user: AuthUser): Promise<AuthTokens> {
    const accessToken = await this.createAccessToken(user);
    const refreshToken = await this.refreshTokenService.create(user);
    return {
      accessToken,
      refreshToken,
      user,
    };
  }

  private createAccessToken(user: AuthUser): Promise<string> {
    const payload: JwtPayload = {
      sub: user.id,
      username: user.username,
      role: user.role,
    };
    return this.jwtService.signAsync(payload, {
      secret: this.configService.get('jwtAccessSecret', { infer: true }),
      expiresIn: this.configService.get('jwtAccessExpiresIn', {
        infer: true,
      }),
    });
  }
}
