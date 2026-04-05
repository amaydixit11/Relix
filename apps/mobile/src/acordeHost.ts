import { NativeModules } from 'react-native';

const DEFAULT_ACORDE_URL = 'http://localhost:7331';

function getMetroScriptUrl(): string | null {
  const scriptURL = NativeModules?.SourceCode?.scriptURL;
  return typeof scriptURL === 'string' && scriptURL.length > 0 ? scriptURL : null;
}

export function detectAcordeUrl(): string {
  const scriptUrl = getMetroScriptUrl();
  if (!scriptUrl) return DEFAULT_ACORDE_URL;

  try {
    const parsed = new URL(scriptUrl);
    const hostname = parsed.hostname;
    if (!hostname) return DEFAULT_ACORDE_URL;
    return `http://${hostname}:7331`;
  } catch {
    return DEFAULT_ACORDE_URL;
  }
}

export async function resolveAcordeUrl(
  getStoredUrl: () => Promise<string | null>
): Promise<string> {
  const storedUrl = await getStoredUrl();
  if (storedUrl && storedUrl.trim().length > 0) {
    return storedUrl;
  }

  return detectAcordeUrl();
}

