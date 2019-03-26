var resourceName;
var radar;
var fastDisplayTimeout = null;

$(function() {
	init();

	window.addEventListener("message", function(_e) {
		var e = _e.data;

		for (var cb of callbacks) {
			if (e.context === cb.context) {
				try {
					cb.cb(e);
				} catch (ex) {
					console.log("error calling cb");
					console.error(ex);
				}
				break;
			}
		}
	});
});

function Callback(context, func) {
	this.context = context;
	this.cb = func;
}

function provideResource(e) {
	resourceName = e.resource;
}

function calcInfo(e) {
	radar = e.info;

	// radar on/off
	if (radar.enable && radar.inPolice) {
		$("#radar").show();
	} else {
		$("#radar").hide();
	}

	// colors of the buttons
	const colorEnabled = "rgba(255, 65, 65, 1)";
	const colorDisabled = "rgba(155, 30, 30, 1)";

	if (radar.frozen) {
		$("#option-freeze p").css("color", colorEnabled);
	}
	else {
		$("#option-freeze p").css("color", colorDisabled);
	}

	if (radar.sType === "mph") {
		$("#option-mph p").css("color", colorEnabled);
		$("#option-kmh p").css("color", colorDisabled);
	}
	else {
		$("#option-mph p").css("color", colorDisabled);
		$("#option-kmh p").css("color", colorEnabled);
	}

	if (radar.frozen) {
		return;
	}
	// setting radar information
	$("#target .speed").html(Math.round(msToSpeed(radar.lastSpeed)));
	if (fastDisplayTimeout === null) {
		$("#fast .speed").html(Math.round(msToSpeed(radar.fastSpeed)));
	}
	$("#patrol .speed").html(Math.round(msToSpeed(radar.patrolS)));
}
var callbacks = [
	new Callback("resource", provideResource),
	new Callback("send_info", calcInfo)
];

function init() {
	$("#radar").hide();

	// used for window keydown events
	$(window).keydown(function(e) {
		if (e.keyCode === 27) // esc key down
			send("radar", {exit: true});
		if (e.keyCode === 37 || e.keyCode === 39)
			send("radar", {rotX: true, offset: e.keyCode - 39 ? -1.0 : 1.0});
		if (e.keyCode === 38 || e.keyCode === 40)
			send("radar", {rotY: true, offset: e.keyCode - 40 ? -1.0 : 1.0});
	});

	// for NUI to LUA callbacks
	$("#option-rotx .left").click(function() {
		send("radar", {rotX: true, offset: -1.0});
	});
	$("#option-rotx .right").click(function() {
		send("radar", {rotX: true, offset: 1.0});
	});

	$("#option-roty .left").click(function() {
		send("radar", {rotY: true, offset: 1.0});
	});
	$("#option-roty .right").click(function() {
		send("radar", {rotY: true, offset: -1.0});
	});

	$("#option-freeze button").click(function() {
		send("radar", {freezeRadar: true});
	});

	$("#option-mph button").click(function() {
		if (radar.sType === "mph") return;
		send("radar", {changeSpeedType: true, sType: "mph"});
	});
	$("#option-kmh button").click(function() {
		if (radar.sType === "kmh") return;
		send("radar", {changeSpeedType: true, sType: "kmh"});
	});

	$("#option-fast .left").click(function() {
		if (radar.minFast <= 0) return;

		var newFast = radar.minFast - radar.increment;
		if (newFast <= 0) newFast = 0;

		displayFastSpeed(newFast);
		send("radar", {setFastSpeed: true, fastSpeed: newFast});
	});
	$("#option-fast .right").click(function() {
		if (radar.minFast > 67.056) return;

		var newFast = radar.minFast + radar.increment;
		if (newFast > 67.056) newFast = 67.056; // 150 mph

		displayFastSpeed(newFast);
		send("radar", {setFastSpeed: true, fastSpeed: newFast});
	});
	$("#option-reset button").click(function() {
		send("radar", {reset: true});
	});
	$("#option-power button").click(function() {
		send("radar", {hide: true});
	});
}

function send(name, data) {
	$.post("http://" + resourceName + "/" + name, JSON.stringify(data), function(datab) {
		if (datab !== "OK")
			console.log(datab);
	});
}

function msToSpeed(ms) {
	const mphC = 2.23694;
	const kmhC = 3.6;

	if (radar.sType === "mph") {
		return ms * mphC;
	} else if (radar.sType === "kmh") {
		return ms * kmhC;
	}
}
function displayFastSpeed(ms) {
	var speed = msToSpeed(ms);
	if (fastDisplayTimeout !== null)
		clearTimeout(fastDisplayTimeout);
	fastDisplayTimeout = setTimeout(function() {fastDisplayTimeout = null;}, 3500);
	$("#fast .speed").html(Math.round(speed));
}
