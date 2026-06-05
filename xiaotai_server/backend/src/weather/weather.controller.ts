import { Controller, Get, Query } from "@nestjs/common";
import { ApiOperation, ApiTags } from "@nestjs/swagger";

import { Public } from "../common/decorators/public.decorator";
import { WeatherLocationQueryDto } from "./dto/weather-query.dto";
import { WeatherService } from "./weather.service";

@ApiTags("Weather")
@Public()
@Controller("weather")
export class WeatherController {
  constructor(private readonly weatherService: WeatherService) {}

  @Get("now")
  @ApiOperation({ summary: "获取当前位置实时天气" })
  now(@Query() query: WeatherLocationQueryDto) {
    return this.weatherService.now(query.location);
  }

  @Get("indices")
  @ApiOperation({ summary: "获取当前位置生活天气指数" })
  indices(@Query() query: WeatherLocationQueryDto) {
    return this.weatherService.indices(query.location);
  }
}
