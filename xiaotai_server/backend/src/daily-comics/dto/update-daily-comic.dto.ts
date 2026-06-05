import { PartialType } from '@nestjs/swagger';

import { CreateDailyComicDto } from './create-daily-comic.dto';

export class UpdateDailyComicDto extends PartialType(CreateDailyComicDto) {}
