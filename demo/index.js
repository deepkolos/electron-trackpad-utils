function triggerFeedback() {
	window.electronAPI.send("toMain", "triggerFeedback");
}

window.electronAPI.receive("fromMain", (data) => {
	const log = document.getElementById("log");
	if (data.command === "onTrackpadScroll") {
		log.innerText = `${data.command}: deltaX: ${data.event.deltaX.toFixed(3)}, deltaY: ${data.event.deltaY.toFixed(3)}\n` + log.innerText;
	} else {
		log.innerText = data.command + "\n" + log.innerText;
	}
});
