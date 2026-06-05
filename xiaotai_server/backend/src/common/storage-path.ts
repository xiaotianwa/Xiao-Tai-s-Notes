import { isAbsolute, join } from 'node:path';

export function resolveStoragePath(
  storageRoot: string,
  ...segments: string[]
): string {
  const root = isAbsolute(storageRoot)
    ? storageRoot
    : join(process.cwd(), storageRoot);
  return join(root, ...segments);
}
