import { Controller, Get } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';

import { Public } from './common/decorators/public.decorator';

@ApiTags('System')
@Controller()
export class AppController {
  @Public()
  @Get('health')
  @ApiOperation({ summary: '健康检查' })
  health(): { status: 'ok'; service: string; time: string } {
    return {
      status: 'ok',
      service: 'xiaotai-backend',
      time: new Date().toISOString(),
    };
  }
}
