function triggerFeedback() {
	window.electronAPI.send("toMain", "triggerFeedback");
}

window.electronAPI.receive("fromMain", (data) => {
	const logEle = document.getElementById("log");
	if (data.command === "onGesture") {
		const event = data.event;
		let log = "";
		if (event.isScroll) {
			log = `${data.command}: deltaX: ${event.deltaX.toFixed(3)}, deltaY: ${event.deltaY.toFixed(3)}, isTrackpad: ${event.isTrackpad}`;
		} else if (event.isScale) {
			log = `${data.command}: magnification: ${event.magnification.toFixed(3)}`;
		} else if (event.isRotate) {
			log = `${data.command}: rotation: ${event.deltaAngle.toFixed(3)}`;
		}
		logEle.innerText = log + "\n" + logEle.innerText;
	} else {
		logEle.innerText = data.command + "\n" + logEle.innerText;
	}
});
