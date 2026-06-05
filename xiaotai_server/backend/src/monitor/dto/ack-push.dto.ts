import { IsString, MaxLength } from "class-validator";

export class AckPushDto {
  @IsString()
  @MaxLength(120)
  deviceId!: string;

  @IsString()
  @MaxLength(80)
  id!: string;
}
