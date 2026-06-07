import { normalizeDeviceName } from "./device-name";

describe("device name", () => {
  it("keeps meaningful client device names", () => {
    expect(normalizeDeviceName("Xiaomi 15", "android", "device_123456")).toBe(
      "Xiaomi 15",
    );
  });

  it("replaces localhost with a platform fallback and stable suffix", () => {
    expect(normalizeDeviceName("localhost", "android", "device_123456")).toBe(
      "Android 设备 123456",
    );
  });
});
