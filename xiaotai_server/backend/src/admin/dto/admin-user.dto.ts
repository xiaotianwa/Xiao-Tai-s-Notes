import { IsIn, IsOptional, IsString, Length, Matches } from "class-validator";

export class CreateAdminUserDto {
  @IsString()
  @Length(3, 32)
  @Matches(/^[a-zA-Z0-9_.-]+$/)
  username!: string;

  @IsString()
  @Length(1, 50)
  nickname!: string;

  @IsString()
  @Length(8, 128)
  password!: string;

  @IsOptional()
  @IsIn(["user", "admin"])
  role: "user" | "admin" = "user";

  @IsOptional()
  @IsIn(["active", "disabled"])
  status: "active" | "disabled" = "active";
}

export class ResetAdminUserPasswordDto {
  @IsString()
  @Length(8, 128)
  password!: string;
}

export class UpdateAdminUserStatusDto {
  @IsIn(["active", "disabled"])
  status!: "active" | "disabled";
}
