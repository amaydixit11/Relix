export interface RuntimeStorageAdapter {
  getItem(key: string): Promise<string | null>;
  setItem(key: string, value: string): Promise<void>;
  removeItem(key: string): Promise<void>;
}

class MemoryStorageAdapter implements RuntimeStorageAdapter {
  private store = new Map<string, string>();

  async getItem(key: string): Promise<string | null> {
    return this.store.get(key) ?? null;
  }

  async setItem(key: string, value: string): Promise<void> {
    this.store.set(key, value);
  }

  async removeItem(key: string): Promise<void> {
    this.store.delete(key);
  }
}

class BrowserStorageAdapter implements RuntimeStorageAdapter {
  async getItem(key: string): Promise<string | null> {
    return window.localStorage.getItem(key);
  }

  async setItem(key: string, value: string): Promise<void> {
    window.localStorage.setItem(key, value);
  }

  async removeItem(key: string): Promise<void> {
    window.localStorage.removeItem(key);
  }
}

let runtimeStorage: RuntimeStorageAdapter | null = null;

function detectDefaultStorage(): RuntimeStorageAdapter {
  if (runtimeStorage) return runtimeStorage;

  if (typeof window !== 'undefined' && window.localStorage) {
    runtimeStorage = new BrowserStorageAdapter();
    return runtimeStorage;
  }

  runtimeStorage = new MemoryStorageAdapter();
  return runtimeStorage;
}

export function configureRuntimeStorage(adapter: RuntimeStorageAdapter) {
  runtimeStorage = adapter;
}

export function getRuntimeStorage(): RuntimeStorageAdapter {
  return detectDefaultStorage();
}
