// Spec sheet toggle and version selector. Loaded as an ES module, so it runs once the
// document is parsed. The toggle lives at the bottom of the sheet; when opening the spec
// sheet leaves it off-screen (below on narrow screens, or above on wide screens), scroll
// to it and move focus there.

const toggle = document.querySelector(".sheet-toggle");
const sheet = document.getElementById("typesheet");

toggle?.addEventListener("click", () => {
	sheet.hidden = !sheet.hidden;
	toggle.setAttribute("aria-expanded", String(!sheet.hidden));
	if (!sheet.hidden) {
		const rect = sheet.getBoundingClientRect();
		if (rect.top > innerHeight - 80 || rect.bottom < 80) {
			sheet.scrollIntoView({ block: "start" });
			sheet.focus({ preventScroll: true });
		}
	}
});

const versionSelect = document.querySelector(".version-select");
versionSelect?.addEventListener("change", () => {
	const url = versionSelect.value;
	if (!url) return;
	window.open(url, "_blank", "noopener");
	versionSelect.value = "";
});
