import React, { PropsWithChildren } from 'react';
import { IIdleTimer, IIdleTimerProps } from '.';
/**
 * IdleTimer Context.
 */
export declare const IdleTimerContext: React.Context<IIdleTimer>;
/**
 * Context interface Type.
 */
export declare type IIdleTimerContext = typeof IdleTimerContext;
/**
 * Provider for adding IdleTimer to Children.
 *
 * @param props  IdleTimer configuration
 * @returns Component wrapped with IdleTimer
 */
export declare function IdleTimerProvider(props?: PropsWithChildren<IIdleTimerProps>): JSX.Element;
/**
 * Context consumer for using IdleTimer API within jsx.
 *
 * @returns IdleTimer context consumer
 */
export declare const IdleTimerConsumer: React.Consumer<IIdleTimer>;
/**
 * Context getter for IdleTimer Provider.
 *
 * @returns IdleTimer API
 */
export declare function useIdleTimerContext(): IIdleTimer;
