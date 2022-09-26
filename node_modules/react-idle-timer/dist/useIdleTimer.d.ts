import { IIdleTimer } from './types/IIdleTimer';
import { IIdleTimerProps } from './types/IIdleTimerProps';
/**
 * Creates an IdleTimer instance.
 *
 * @param props Configuration options
 * @returns IdleTimer
 */
export declare function useIdleTimer({ timeout, promptTimeout, element, events, timers, immediateEvents, onPrompt, onIdle, onActive, onAction, onMessage, debounce, throttle, eventsThrottle, startOnMount, startManually, stopOnIdle, crossTab, name, syncTimers, leaderElection }?: IIdleTimerProps): IIdleTimer;
