import { Image } from 'antd';
import { useEffect, useState } from 'react';

import { requestBlob } from '../api/client';

interface MediaThumbProps {
  mediaId: string;
  size?: number;
  rounded?: number;
  alt?: string;
  preview?: boolean;
}

/**
 * 异步拉取 /admin/media/{id}/thumb 并渲染为缩略图。
 * 拉取失败或加载中，显示「图」占位符（与 MediaPage 风格一致）。
 */
export default function MediaThumb({
  mediaId,
  size = 64,
  rounded = 8,
  alt = '图片',
  preview = false,
}: MediaThumbProps): React.JSX.Element {
  const [src, setSrc] = useState<string>();
  const [failed, setFailed] = useState(false);

  useEffect(() => {
    let active = true;
    let objectUrl: string | undefined;
    setFailed(false);
    setSrc(undefined);
    if (!mediaId) {
      return;
    }
    requestBlob(`/admin/media/${encodeURIComponent(mediaId)}/thumb`)
      .then((blob) => {
        if (!active) {
          return;
        }
        objectUrl = URL.createObjectURL(blob);
        setSrc(objectUrl);
      })
      .catch(() => {
        if (active) {
          setFailed(true);
        }
      });
    return () => {
      active = false;
      if (objectUrl) {
        URL.revokeObjectURL(objectUrl);
      }
    };
  }, [mediaId]);

  if (failed || !mediaId) {
    return (
      <div
        className="media-thumb-placeholder"
        style={{
          width: size,
          height: size,
          borderRadius: rounded,
          display: 'inline-flex',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        图
      </div>
    );
  }

  if (!src) {
    return (
      <div
        className="media-thumb-placeholder"
        style={{
          width: size,
          height: size,
          borderRadius: rounded,
          display: 'inline-flex',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        ...
      </div>
    );
  }

  return (
    <Image
      src={src}
      alt={alt}
      width={size}
      height={size}
      style={{ objectFit: 'cover', borderRadius: rounded }}
      preview={preview}
    />
  );
}
