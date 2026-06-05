import { Controller, Get, Req } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import type { Request } from 'express';

import type { AuthUser } from '../auth/auth-user';
import { Roles } from '../common/decorators/roles.decorator';

interface AuthenticatedRequest extends Request {
  user: AuthUser;
}

@ApiTags('Users')
@Controller('users')
export class UsersController {
  @Get('me')
  @ApiBearerAuth()
  @ApiOperation({ summary: '获取当前用户资料' })
  me(@Req() request: AuthenticatedRequest): AuthUser {
    return request.user;
  }

  @Get('admin-check')
  @Roles('admin')
  @ApiBearerAuth()
  @ApiOperation({ summary: '管理员权限检查' })
  adminCheck(): { ok: true } {
    return { ok: true };
  }
}
