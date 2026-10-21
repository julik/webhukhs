// Webhukhs admin - copy buttons and the body viewer tabs. No framework, the CSP only allows this file.

const flash = (element) => {
  element.classList.add("copied");
  setTimeout(() => element.classList.remove("copied"), 1200);
};

const tabsOf = (tablist) => Array.from(tablist.querySelectorAll("[role=tab]"));

const selectTab = (tab) => {
  for (const other of tabsOf(tab.closest("[role=tablist]"))) {
    const selected = other === tab;
    other.setAttribute("aria-selected", String(selected));
    other.tabIndex = selected ? 0 : -1;
    document.getElementById(other.getAttribute("aria-controls")).hidden = !selected;
  }
};

document.addEventListener("click", (event) => {
  const copy = event.target.closest(".btn-copy");
  if (copy) {
    navigator.clipboard.writeText(copy.dataset.copy).then(() => flash(copy));
    return;
  }

  const tab = event.target.closest("[role=tab]");
  if (tab) {
    selectTab(tab);
    return;
  }

  const copyPanel = event.target.closest(".btn-copy-panel");
  if (copyPanel) {
    const panel = copyPanel.closest(".tabs").querySelector("[role=tabpanel]:not([hidden])");
    navigator.clipboard.writeText(panel.querySelector("code").textContent).then(() => flash(copyPanel));
  }
});

// Arrow keys move between tabs, as the ARIA tabs pattern expects
document.addEventListener("keydown", (event) => {
  const tab = event.target.closest("[role=tab]");
  if (!tab || !["ArrowLeft", "ArrowRight"].includes(event.key)) return;

  const tabs = tabsOf(tab.closest("[role=tablist]"));
  const step = event.key === "ArrowRight" ? 1 : -1;
  const next = tabs[(tabs.indexOf(tab) + step + tabs.length) % tabs.length];
  selectTab(next);
  next.focus();
});
