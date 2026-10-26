// Webhukhs admin - copy buttons, the body viewer tabs and the index auto-refresh. No framework, the CSP only allows this file.

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

// Auto-refresh of the index. Polls rather than holding an EventSource open: a forgotten tab with
// an SSE stream pins a server thread forever, a forgotten tab polling costs one request now and then.
const POLL_INTERVAL_MS = 5000;
const POLL_STORAGE_KEY = "webhukhs.autoRefresh";

const autoRefresh = document.getElementById("auto-refresh");
let pollTimer = null;
let pollAbort = null;

const stopPolling = () => {
  clearTimeout(pollTimer);
  pollTimer = null;
  pollAbort?.abort();
  pollAbort = null;
};

const schedulePoll = () => {
  pollTimer = setTimeout(refreshListing, POLL_INTERVAL_MS);
};

const refreshListing = async () => {
  // Nobody is looking, so check again later instead
  if (document.hidden) return schedulePoll();

  const abort = (pollAbort = new AbortController());
  try {
    const response = await fetch(location.href, {signal: abort.signal, headers: {Accept: "text/html"}});
    const html = await response.text();
    // Swapped synchronously after the last await, so a switch turned off meanwhile has aborted us
    const fresh = new DOMParser().parseFromString(html, "text/html").getElementById("received-webhooks");
    if (response.ok && fresh) document.getElementById("received-webhooks").replaceWith(fresh);
  } catch (error) {
    if (abort.signal.aborted) return;
  }
  if (pollAbort === abort) schedulePoll();
};

const rememberAutoRefresh = (enabled) => {
  try {
    localStorage.setItem(POLL_STORAGE_KEY, enabled ? "1" : "");
  } catch {}
};

const recallAutoRefresh = () => {
  try {
    return localStorage.getItem(POLL_STORAGE_KEY) === "1";
  } catch {
    return false;
  }
};

if (autoRefresh) {
  autoRefresh.checked = recallAutoRefresh();
  if (autoRefresh.checked) schedulePoll();

  autoRefresh.addEventListener("change", () => {
    stopPolling();
    rememberAutoRefresh(autoRefresh.checked);
    if (autoRefresh.checked) refreshListing();
  });
}
