import { Body, Controller, Post } from "@nestjs/common";
import { ApiOperation, ApiTags } from "@nestjs/swagger";

import { Public } from "../common/decorators/public.decorator";
import { AiService } from "./ai.service";
import { AiChatDto } from "./dto/ai-chat.dto";

@ApiTags("AI")
@Public()
@Controller("ai")
export class AiController {
  constructor(private readonly aiService: AiService) {}

  @Post("chat")
  @ApiOperation({ summary: "AI 小助手聊天" })
  chat(@Body() body: AiChatDto) {
    return this.aiService.chat(body.message);
  }
}
