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
import { AckPushDto } from "./dto/ack-push.dto";
import { CreatePushDto, UpdatePushDto } from "./dto/create-push.dto";
import {
  PendingPushQueryDto,
  QueryMonitorDevicesDto,
  QueryMonitorUsageDto,
  QueryPushDto,
} from "./dto/query-monitor.dto";
import { MonitorService } from "./monitor.service";

interface AuthenticatedRequest extends Request {
  user: AuthUser;
}

@ApiTags("Monitor")
@ApiBearerAuth()
@Controller("monitor")
export class MonitorController {
  constructor(private readonly monitorService: MonitorService) {}

  @Get("devices")
  @Roles("admin")
  @ApiOperation({ summary: "管理端设备监控概览" })
  listDevices(@Query() query: QueryMonitorDevicesDto) {
    return this.monitorService.listDevices(query);
  }

  @Get("usage/latest")
  @Roles("admin")
  @ApiOperation({ summary: "管理端查看设备最近使用上报" })
  latestUsage(@Query() query: QueryMonitorUsageDto) {
    return this.monitorService.latestUsage(query);
  }

  @Get("usage")
  @Roles("admin")
  @ApiOperation({ summary: "管理端查看设备使用上报列表" })
  listUsage(@Query() query: QueryMonitorUsageDto) {
    return this.monitorService.listUsage(query);
  }

  @Get("push/pending")
  @ApiOperation({ summary: "手机端轮询待展示强提醒" })
  pendingPushes(
    @Req() request: AuthenticatedRequest,
    @Query() query: PendingPushQueryDto,
  ) {
    return this.monitorService.pendingPushes(request.user, query.deviceId);
  }

  @Post("push/ack")
  @ApiOperation({ summary: "手机端确认强提醒已展示" })
  ackPush(@Req() request: AuthenticatedRequest, @Body() body: AckPushDto) {
    return this.monitorService.ackPush(request.user, body);
  }

  @Post("push")
  @Roles("admin")
  @ApiOperation({ summary: "管理端发布强提醒" })
  createPush(
    @Req() request: AuthenticatedRequest,
    @Body() body: CreatePushDto,
  ) {
    return this.monitorService.createPush(request.user, request, body);
  }

  @Get("push")
  @Roles("admin")
  @ApiOperation({ summary: "管理端强提醒列表" })
  listPushes(@Query() query: QueryPushDto) {
    return this.monitorService.listPushes(query);
  }

  @Patch("push/:id")
  @Roles("admin")
  @ApiOperation({ summary: "管理端修改或启停强提醒" })
  updatePush(
    @Param("id") id: string,
    @Req() request: AuthenticatedRequest,
    @Body() body: UpdatePushDto,
  ) {
    return this.monitorService.updatePush(id, request.user, request, body);
  }

  @Delete("push/:id")
  @Roles("admin")
  @ApiOperation({ summary: "管理端撤销强提醒" })
  deletePush(@Param("id") id: string, @Req() request: AuthenticatedRequest) {
    return this.monitorService.deletePush(id, request.user, request);
  }
}
