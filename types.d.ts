declare module "@deepkolos/electron-trackpad-utils" {
	export function onTrackpadScrollBegan(callback: () => void): void;
	export function onTrackpadScrollEnded(callback: () => void): void;
	export function onScroll(callback: (event: { deltaX: number, deltaY: number, isTrackpad: boolean }) => void): void;
	export function onForceClick(callback: () => void): void;
	export function triggerFeedback(): void;
}
