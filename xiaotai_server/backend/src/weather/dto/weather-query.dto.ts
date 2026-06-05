import { IsOptional, IsString, MaxLength } from "class-validator";

export class WeatherLocationQueryDto {
  @IsOptional()
  @IsString()
  @MaxLength(64)
  location?: string;
}
