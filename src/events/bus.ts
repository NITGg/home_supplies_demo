import type { AppEvents } from "@/types/events";
import { EventEmitter } from "node:events";

type EventName = keyof AppEvents;

class AppEventBus {
  private readonly emitter = new EventEmitter();

  constructor() {
    this.emitter.setMaxListeners(50);
  }

  on<K extends EventName>(name: K, handler: (payload: AppEvents[K]) => void) {
    this.emitter.on(name as string, handler as (...args: any[]) => void);
  }

  once<K extends EventName>(name: K, handler: (payload: AppEvents[K]) => void) {
    this.emitter.once(name as string, handler as (...args: any[]) => void);
  }

  emit<K extends EventName>(name: K, payload: AppEvents[K]) {
    this.emitter.emit(name as string, payload);
  }
}

export const bus = new AppEventBus();
