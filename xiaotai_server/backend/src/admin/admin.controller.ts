import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Query,
  Req,
} from "@nestjs/common";
import { ApiBearerAuth, ApiOperation, ApiTags } from "@nestjs/swagger";
import type { Request } from "express";

import type { AuthUser } from "../auth/auth-user";
import { Roles } from "../common/decorators/roles.decorator";
import { AdminService } from "./admin.service";
import {
  AdminAuditLogsQueryDto,
  AdminItemsQueryDto,
  AdminUsersQueryDto,
} from "./dto/admin-query.dto";
import {
  CreateAdminUserDto,
  ResetAdminUserPasswordDto,
  UpdateAdminUserStatusDto,
} from "./dto/admin-user.dto";

interface AuthenticatedRequest extends Request {
  user: AuthUser;
}

@ApiTags("Admin")
@ApiBearerAuth()
@Roles("admin")
@Controller("admin")
export class AdminController {
  constructor(private readonly adminService: AdminService) {}

  @Get("dashboard")
  @ApiOperation({ summary: "管理端仪表盘" })
  dashboard() {
    return this.adminService.dashboard();
  }

  @Get("users")
  @ApiOperation({ summary: "管理端用户列表" })
  users(@Query() query: AdminUsersQueryDto) {
    return this.adminService.listUsers(query);
  }

  @Post("users")
  @ApiOperation({ summary: "管理端创建 APP 用户" })
  createUser(
    @Body() dto: CreateAdminUserDto,
    @Req() request: AuthenticatedRequest,
  ) {
    return this.adminService.createUser(dto, request.user, request);
  }

  @Get("users/:id")
  @ApiOperation({ summary: "管理端用户详情" })
  userDetail(@Param("id") id: string, @Req() request: AuthenticatedRequest) {
    return this.adminService.getUserDetail(id, request.user, request);
  }

  @Patch("users/:id/password")
  @ApiOperation({ summary: "管理端重置用户密码" })
  resetUserPassword(
    @Param("id") id: string,
    @Body() dto: ResetAdminUserPasswordDto,
    @Req() request: AuthenticatedRequest,
  ) {
    return this.adminService.resetUserPassword(id, dto, request.user, request);
  }

  @Patch("users/:id/status")
  @ApiOperation({ summary: "管理端启用或停用用户" })
  updateUserStatus(
    @Param("id") id: string,
    @Body() dto: UpdateAdminUserStatusDto,
    @Req() request: AuthenticatedRequest,
  ) {
    return this.adminService.updateUserStatus(id, dto, request.user, request);
  }

  @Delete("users/:id")
  @ApiOperation({ summary: "管理端删除用户及关联内容" })
  deleteUser(@Param("id") id: string, @Req() request: AuthenticatedRequest) {
    return this.adminService.deleteUser(id, request.user, request);
  }

  @Get("users/:id/items")
  @ApiOperation({ summary: "管理端用户同步数据列表" })
  userItems(@Param("id") id: string, @Query() query: AdminItemsQueryDto) {
    return this.adminService.listUserItems(id, query);
  }

  @Get("items")
  @ApiOperation({ summary: "管理端同步数据列表" })
  items(@Query() query: AdminItemsQueryDto) {
    return this.adminService.listItems(query);
  }

  @Get("items/:id")
  @ApiOperation({ summary: "管理端同步数据详情" })
  itemDetail(@Param("id") id: string, @Req() request: AuthenticatedRequest) {
    return this.adminService.getItemDetail(id, request.user, request);
  }

  @Delete("items/:id")
  removeItem(@Param("id") id: string, @Req() request: AuthenticatedRequest) {
    return this.adminService.softDeleteItem(id, request.user, request);
  }

  @Get("audit-logs")
  @ApiOperation({ summary: "管理端操作日志" })
  auditLogs(@Query() query: AdminAuditLogsQueryDto) {
    return this.adminService.listAuditLogs(query);
  }
}
