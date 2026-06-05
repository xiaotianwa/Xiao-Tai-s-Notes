import { ApiProperty } from '@nestjs/swagger';
import { IsString, Length } from 'class-validator';

export class LoginDto {
  @ApiProperty({ example: 'admin' })
  @IsString()
  @Length(2, 50)
  username!: string;

  @ApiProperty({ example: 'change-me-now' })
  @IsString()
  @Length(8, 128)
  password!: string;
}
