import React, { ComponentType } from 'react';
import { IIdleTimer, IIdleTimerProps } from '.';
/**
 * Higher Order Component (HOC) for adding IdleTimer.
 *
 * @param props  IdleTimer configuration.
 * @returns Component wrapped with IdleTimer.
 */
export declare function withIdleTimer<T extends IIdleTimer>(Component: ComponentType<T>): React.ForwardRefExoticComponent<React.PropsWithoutRef<Omit<T, keyof IIdleTimer> & IIdleTimerProps> & React.RefAttributes<IIdleTimer>>;
