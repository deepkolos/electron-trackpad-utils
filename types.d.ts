declare module "@deepkolos/electron-trackpad-utils" {
	export function onTrackpadScrollBegan(callback: () => void): void;
	export function onTrackpadScrollEnded(callback: () => void): void;
	export function onGesture(callback: (event: {
		deltaX: number,
		deltaY: number,
		isTrackpad: boolean,
		isScroll: boolean,
		isScale: boolean,
		isRotate: boolean,
		magnification: number,
		deltaAngle: number
	}) => void): void;
	export function onForceClick(callback: () => void): void;
	export function triggerFeedback(): void;
}
