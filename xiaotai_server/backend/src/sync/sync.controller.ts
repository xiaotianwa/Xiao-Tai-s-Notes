import { Body, Controller, Get, Post, Query, Req } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import type { Request } from 'express';

import type { AuthUser } from '../auth/auth-user';
import {
  BatchUploadSyncItemsDto,
  PullSyncItemsDto,
} from './dto/sync-item.dto';
import type {
  BatchUploadSyncItemsResult,
  PullSyncItemsResult,
} from './sync.service';
import { SyncService } from './sync.service';

interface AuthenticatedRequest extends Request {
  user: AuthUser;
}

@ApiTags('Sync')
@ApiBearerAuth()
@Controller('sync')
export class SyncController {
  constructor(private readonly syncService: SyncService) {}

  @Get('items')
  @ApiOperation({ summary: '增量拉取当前用户的同步数据' })
  pullItems(
    @Req() request: AuthenticatedRequest,
    @Query() query: PullSyncItemsDto,
  ): Promise<PullSyncItemsResult> {
    return this.syncService.pullItems(request.user, query);
  }

  @Post('items/batch')
  @ApiOperation({ summary: '批量上传当前设备的同步数据' })
  batchUpload(
    @Req() request: AuthenticatedRequest,
    @Body() body: BatchUploadSyncItemsDto,
  ): Promise<BatchUploadSyncItemsResult> {
    return this.syncService.batchUpload(request.user, body);
  }
}
