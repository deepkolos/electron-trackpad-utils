declare module "@deepkolos/electron-trackpad-utils" {
	export function onTrackpadScrollBegan(callback: () => void): void;
	export function onTrackpadScrollEnded(callback: () => void): void;
	export function onTrackpadScroll(callback: (event: { deltaX: number, deltaY: number }) => void): void;
	export function onForceClick(callback: () => void): void;
	export function triggerFeedback(): void;
}
