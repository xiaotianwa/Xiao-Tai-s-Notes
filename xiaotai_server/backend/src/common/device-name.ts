export function normalizeDeviceName(
  deviceName: string | null | undefined,
  platform: string | null | undefined,
  deviceId: string,
): string {
  const normalizedName = deviceName?.trim();
  if (normalizedName && normalizedName.toLowerCase() !== "localhost") {
    return normalizedName;
  }

  const platformName = platform?.trim().toLowerCase();
  const suffix = deviceId.slice(-6);
  if (platformName === "android") {
    return `Android 设备 ${suffix}`;
  }
  if (platformName === "ios") {
    return `iOS 设备 ${suffix}`;
  }
  return `未知设备 ${suffix}`;
}
