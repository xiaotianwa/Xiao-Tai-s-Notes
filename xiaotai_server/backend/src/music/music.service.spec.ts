import { BadRequestException } from "@nestjs/common";

import { MusicService } from "./music.service";

describe("MusicService", () => {
  const service = new MusicService({} as never, {} as never, {} as never);

  it("rejects create without audio file", async () => {
    await expect(
      service.create({ title: "Track" }, {}, "admin-id"),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it("rejects unsupported audio mime type", async () => {
    await expect(
      service.create(
        { title: "Track" },
        {
          audio: [
            {
              originalname: "track.exe",
              mimetype: "application/octet-stream",
              size: 1024,
              buffer: Buffer.from("x"),
            },
          ],
        },
        "admin-id",
      ),
    ).rejects.toBeInstanceOf(BadRequestException);
  });
});
