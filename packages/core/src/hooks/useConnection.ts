"use client";

import { Fragment, createElement, useEffect, useSyncExternalStore, type ReactNode } from 'react';
import { connectionService } from '../services/ConnectionService';

export function ConnectionProvider({ children }: { children: ReactNode }) {
  useEffect(() => {
    connectionService.start();
    return () => connectionService.stop();
  }, []);

  return createElement(Fragment, null, children);
}

export function useConnectionState() {
  return useSyncExternalStore(
    (listener) => connectionService.subscribe(listener),
    () => connectionService.getState(),
    () => connectionService.getState()
  );
}
