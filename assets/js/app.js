/* ============================================================
   KC Happy Hour — app logic
   ============================================================ */

const DAY_KEYS = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

const state = {
  venues: [],
  filters: {
    cities: new Set(),
    cuisines: new Set(),
    days: new Set(),
  },
  search: "",
  nowOnly: false,
  sort: "relevance",
};

const els = {};

init();

async function init() {
  cacheEls();
  initTheme();
  initClock();
  bindGlobalUI();

  try {
    const res = await fetch("data/venues.json", { cache: "no-store" });
    state.venues = await res.json();
  } catch (e) {
    state.venues = [];
    console.error("Failed to load venues.json", e);
  }

  buildFilterPanels();
  render();
}

function cacheEls() {
  els.searchInput = document.getElementById("searchInput");
  els.nowToggle = document.getElementById("nowToggle");
  els.statsRow = document.getElementById("statsRow");
  els.cityPanel = document.getElementById("cityPanel");
  els.cuisinePanel = document.getElementById("cuisinePanel");
  els.dayPanel = document.getElementById("dayPanel");
  els.sortSelect = document.getElementById("sortSelect");
  els.clearFilters = document.getElementById("clearFilters");
  els.activeChips = document.getElementById("activeChips");
  els.resultsGrid = document.getElementById("resultsGrid");
  els.resultsCount = document.getElementById("resultsCount");
  els.emptyState = document.getElementById("emptyState");
  els.emptyClear = document.getElementById("emptyClear");
  els.footerUpdated = document.getElementById("footerUpdated");
  els.detailOverlay = document.getElementById("detailOverlay");
  els.detailCard = document.getElementById("detailCard");
  els.themeToggle = document.getElementById("themeToggle");
  els.liveClock = document.getElementById("liveClock");
}

/* ---------------- theme ---------------- */

function initTheme() {
  const saved = localStorage.getItem("kchh-theme");
  if (saved) document.documentElement.setAttribute("data-theme", saved);
  els.themeToggle.addEventListener("click", () => {
    const cur = document.documentElement.getAttribute("data-theme") ||
      (window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light");
    const next = cur === "dark" ? "light" : "dark";
    document.documentElement.setAttribute("data-theme", next);
    localStorage.setItem("kchh-theme", next);
  });
}

/* ---------------- clock / "now" ---------------- */

function kcNow() {
  // Kansas City runs on America/Chicago
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: "America/Chicago",
    weekday: "short", hour: "numeric", minute: "numeric", hour12: false,
  }).formatToParts(new Date());
  const map = {};
  parts.forEach((p) => (map[p.type] = p.value));
  const dayShort = map.weekday; // "Mon" etc
  const hour = parseInt(map.hour, 10) % 24;
  const minute = parseInt(map.minute, 10);
  return { day: dayShort, hour, minute, decimalHour: hour + minute / 60 };
}

function initClock() {
  const tick = () => {
    const n = kcNow();
    const h12 = ((n.hour + 11) % 12) + 1;
    const ampm = n.hour >= 12 ? "PM" : "AM";
    const mm = String(n.minute).padStart(2, "0");
    els.liveClock.textContent = `${n.day} ${h12}:${mm} ${ampm} · Kansas City`;
  };
  tick();
  setInterval(tick, 15000);
}

function isHappeningNow(venue) {
  const n = kcNow();
  if (!venue.days || !venue.days.includes(n.day)) return false;
  if (venue.startHour == null || venue.endHour == null) return false;
  if (venue.endHour > venue.startHour) {
    return n.decimalHour >= venue.startHour && n.decimalHour < venue.endHour;
  }
  // overnight wrap (e.g. starts 22, ends 2)
  return n.decimalHour >= venue.startHour || n.decimalHour < venue.endHour;
}

/* ---------------- filter panel construction ---------------- */

const REGION_ORDER = [
  "Downtown & Midtown KC",
  "Northland",
  "Wyandotte County & Border",
  "Overland Park & Leawood",
  "Southern & Eastern Suburbs",
];

function buildFilterPanels() {
  // ---- City panel, grouped by region ----
  const byRegion = new Map();
  state.venues.forEach((v) => {
    if (!byRegion.has(v.region)) byRegion.set(v.region, new Map());
    const cityMap = byRegion.get(v.region);
    cityMap.set(v.city, (cityMap.get(v.city) || 0) + 1);
  });

  let cityHtml = "";
  const regions = [...byRegion.keys()].sort(
    (a, b) => REGION_ORDER.indexOf(a) - REGION_ORDER.indexOf(b)
  );
  regions.forEach((region) => {
    cityHtml += `<div class="filter-panel-group-label">${escapeHtml(region)}</div>`;
    const cities = [...byRegion.get(region).entries()].sort((a, b) => a[0].localeCompare(b[0]));
    cities.forEach(([city, count]) => {
      const id = `city-${slug(city)}`;
      cityHtml += optionRow(id, city, count, "city");
    });
  });
  els.cityPanel.innerHTML = cityHtml;

  // ---- Cuisine panel ----
  const cuisineCounts = new Map();
  state.venues.forEach((v) => cuisineCounts.set(v.cuisine, (cuisineCounts.get(v.cuisine) || 0) + 1));
  const cuisines = [...cuisineCounts.entries()].sort((a, b) => b[1] - a[1]);
  els.cuisinePanel.innerHTML = cuisines
    .map(([c, count]) => optionRow(`cuisine-${slug(c)}`, c, count, "cuisine"))
    .join("");

  // ---- Day panel ----
  els.dayPanel.innerHTML = DAY_KEYS.map((d) => {
    const count = state.venues.filter((v) => v.days && v.days.includes(d)).length;
    return optionRow(`day-${d}`, dayFull(d), count, "day", d);
  }).join("");

  // bind checkboxes
  els.cityPanel.querySelectorAll("input").forEach((cb) =>
    cb.addEventListener("change", () => toggleFilter("cities", cb.dataset.value, cb.checked))
  );
  els.cuisinePanel.querySelectorAll("input").forEach((cb) =>
    cb.addEventListener("change", () => toggleFilter("cuisines", cb.dataset.value, cb.checked))
  );
  els.dayPanel.querySelectorAll("input").forEach((cb) =>
    cb.addEventListener("change", () => toggleFilter("days", cb.dataset.value, cb.checked))
  );
}

function optionRow(id, label, count, type, rawValue) {
  const value = rawValue || label;
  return `
    <label class="filter-option" for="${id}">
      <span class="opt-label">
        <input type="checkbox" id="${id}" data-value="${escapeHtml(value)}">
        ${escapeHtml(label)}
      </span>
      <span class="opt-count">${count}</span>
    </label>`;
}

function dayFull(d) {
  return { Sun: "Sunday", Mon: "Monday", Tue: "Tuesday", Wed: "Wednesday", Thu: "Thursday", Fri: "Friday", Sat: "Saturday" }[d];
}

function toggleFilter(group, value, checked) {
  if (checked) state.filters[group].add(value);
  else state.filters[group].delete(value);
  render();
}

/* ---------------- global UI bindings ---------------- */

function bindGlobalUI() {
  els.searchInput.addEventListener("input", debounce(() => {
    state.search = els.searchInput.value.trim().toLowerCase();
    render();
  }, 120));

  els.nowToggle.addEventListener("click", () => {
    state.nowOnly = !state.nowOnly;
    els.nowToggle.classList.toggle("active", state.nowOnly);
    render();
  });

  els.sortSelect.addEventListener("change", () => {
    state.sort = els.sortSelect.value;
    render();
  });

  els.clearFilters.addEventListener("click", clearAllFilters);
  els.emptyClear.addEventListener("click", clearAllFilters);

  document.querySelectorAll(".filter-head").forEach((btn) => {
    btn.addEventListener("click", (e) => {
      e.stopPropagation();
      const panel = document.getElementById(btn.dataset.target);
      const isOpen = panel.classList.contains("open");
      closeAllPanels();
      if (!isOpen) {
        panel.classList.add("open");
        btn.classList.add("open");
      }
    });
  });
  document.addEventListener("click", closeAllPanels);

  els.detailOverlay.addEventListener("click", (e) => {
    if (e.target === els.detailOverlay) closeDetail();
  });
  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape") closeDetail();
  });
}

function closeAllPanels() {
  document.querySelectorAll(".filter-panel.open").forEach((p) => p.classList.remove("open"));
  document.querySelectorAll(".filter-head.open").forEach((b) => b.classList.remove("open"));
}

function clearAllFilters() {
  state.filters.cities.clear();
  state.filters.cuisines.clear();
  state.filters.days.clear();
  state.search = "";
  state.nowOnly = false;
  els.searchInput.value = "";
  els.nowToggle.classList.remove("active");
  document.querySelectorAll('.filter-panel input[type="checkbox"]').forEach((cb) => (cb.checked = false));
  render();
}

/* ---------------- filtering / sorting ---------------- */

function getFiltered() {
  let list = state.venues;

  if (state.filters.cities.size) {
    list = list.filter((v) => state.filters.cities.has(v.city));
  }
  if (state.filters.cuisines.size) {
    list = list.filter((v) => state.filters.cuisines.has(v.cuisine));
  }
  if (state.filters.days.size) {
    list = list.filter((v) => v.days && v.days.some((d) => state.filters.days.has(d)));
  }
  if (state.nowOnly) {
    list = list.filter(isHappeningNow);
  }
  if (state.search) {
    const q = state.search;
    list = list.filter((v) =>
      [v.name, v.city, v.cuisine, v.address, dealsAsString(v.deals)]
        .join(" ")
        .toLowerCase()
        .includes(q)
    );
  }

  const sorted = [...list];
  if (state.sort === "name") sorted.sort((a, b) => a.name.localeCompare(b.name));
  else if (state.sort === "city") sorted.sort((a, b) => a.city.localeCompare(b.city) || a.name.localeCompare(b.name));
  else if (state.sort === "start") sorted.sort((a, b) => (a.startHour ?? 99) - (b.startHour ?? 99));
  else {
    // relevance: happening-now first, then name
    sorted.sort((a, b) => {
      const an = isHappeningNow(a) ? 0 : 1;
      const bn = isHappeningNow(b) ? 0 : 1;
      if (an !== bn) return an - bn;
      return a.name.localeCompare(b.name);
    });
  }
  return sorted;
}

/* ---------------- rendering ---------------- */

function render() {
  const filtered = getFiltered();
  renderStats();
  renderChips();
  renderFilterHeads();
  renderGrid(filtered);
}

function renderStats() {
  const total = state.venues.length;
  const cities = new Set(state.venues.map((v) => v.city)).size;
  const nowCount = state.venues.filter(isHappeningNow).length;
  els.statsRow.innerHTML = `
    <span><b>${total}</b> happy hours tracked</span>
    <span><b>${cities}</b> neighborhoods</span>
    <span><b>${nowCount}</b> happening right now</span>
  `;
}

function renderFilterHeads() {
  document.querySelector('[data-target="cityPanel"]').classList.toggle("has-selection", !!state.filters.cities.size);
  document.querySelector('[data-target="cuisinePanel"]').classList.toggle("has-selection", !!state.filters.cuisines.size);
  document.querySelector('[data-target="dayPanel"]').classList.toggle("has-selection", !!state.filters.days.size);
}

function renderChips() {
  const chips = [];
  state.filters.cities.forEach((c) => chips.push({ group: "cities", value: c, label: c }));
  state.filters.cuisines.forEach((c) => chips.push({ group: "cuisines", value: c, label: c }));
  state.filters.days.forEach((d) => chips.push({ group: "days", value: d, label: dayFull(d) }));

  els.activeChips.innerHTML = chips
    .map(
      (c, i) => `<span class="chip" data-i="${i}">${escapeHtml(c.label)}<button data-group="${c.group}" data-value="${escapeHtml(c.value)}">&times;</button></span>`
    )
    .join("");

  els.activeChips.querySelectorAll("button").forEach((btn) => {
    btn.addEventListener("click", () => {
      state.filters[btn.dataset.group].delete(btn.dataset.value);
      const cb = document.querySelector(`.filter-panel input[data-value="${cssEscape(btn.dataset.value)}"]`);
      if (cb) cb.checked = false;
      render();
    });
  });
}

function renderGrid(list) {
  els.resultsCount.innerHTML = `Showing <b>${list.length}</b> of ${state.venues.length} happy hours`;
  els.emptyState.hidden = list.length !== 0;
  els.resultsGrid.innerHTML = list.map(cardHtml).join("");

  els.resultsGrid.querySelectorAll(".card").forEach((card) => {
    card.addEventListener("click", () => openDetail(list[+card.dataset.i]));
  });
}

function cardHtml(v, i) {
  const now = isHappeningNow(v);
  return `
    <article class="card" data-i="${i}" tabindex="0">
      <div class="card-top">
        <h3 class="card-name">${escapeHtml(v.name)}</h3>
        ${now ? `<span class="now-badge"><span class="dot"></span>Now</span>` : ""}
      </div>
      <div class="card-tags">
        <span class="tag tag-city">${escapeHtml(v.city)}</span>
        <span class="tag tag-cuisine">${escapeHtml(v.cuisine)}</span>
      </div>
      <div class="card-time">
        <span class="days">${formatDays(v.days)}</span>
        <span>${escapeHtml(v.hoursDisplay || "")}</span>
      </div>
      <div class="card-deals"><b>Deals:</b> ${escapeHtml(dealsAsString(v.deals))}</div>
      <div class="card-addr">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 10c0 7-9 12-9 12s-9-5-9-12a9 9 0 1118 0z"/><circle cx="12" cy="10" r="3"/></svg>
        ${escapeHtml(v.address || "")}
      </div>
    </article>`;
}

function formatDays(days) {
  if (!days || !days.length) return "";
  if (days.length === 7) return "Every day";
  if (days.length === 5 && ["Mon","Tue","Wed","Thu","Fri"].every((d) => days.includes(d))) return "Mon–Fri";
  return days.join(", ");
}

function dealsAsString(deals) {
  if (!deals) return "Ask server for happy hour specials";
  if (Array.isArray(deals)) return deals.join(" · ");
  return deals;
}

/* ---------------- detail overlay ---------------- */

function openDetail(v) {
  const now = isHappeningNow(v);
  const dealsList = Array.isArray(v.deals) ? v.deals : v.deals ? [v.deals] : [];
  els.detailCard.innerHTML = `
    <button class="detail-close" id="detailClose">&times;</button>
    <h2 class="detail-name">${escapeHtml(v.name)}</h2>
    <div class="detail-tags">
      <span class="tag tag-city">${escapeHtml(v.city)}</span>
      <span class="tag tag-cuisine">${escapeHtml(v.cuisine)}</span>
      ${now ? `<span class="now-badge"><span class="dot"></span>Happening now</span>` : ""}
    </div>
    <div class="detail-section">
      <div class="detail-label">Happy hour</div>
      <div class="detail-value">${formatDays(v.days)} &middot; ${escapeHtml(v.hoursDisplay || "")}</div>
    </div>
    ${dealsList.length ? `
    <div class="detail-section">
      <div class="detail-label">Deals</div>
      <ul class="detail-deals-list">${dealsList.map((d) => `<li class="detail-value">${escapeHtml(d)}</li>`).join("")}</ul>
    </div>` : ""}
    <div class="detail-section">
      <div class="detail-label">Address</div>
      <div class="detail-value">${escapeHtml(v.address || "—")}</div>
    </div>
    ${v.source ? `<a class="detail-source" href="${escapeAttr(v.source)}" target="_blank" rel="noopener noreferrer">
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M18 13v6a2 2 0 01-2 2H5a2 2 0 01-2-2V8a2 2 0 012-2h6"/><path d="M15 3h6v6"/><path d="M10 14L21 3"/></svg>
      View source
    </a>` : ""}
  `;
  document.getElementById("detailClose").addEventListener("click", closeDetail);
  els.detailOverlay.classList.add("open");
}

function closeDetail() {
  els.detailOverlay.classList.remove("open");
}

/* ---------------- utils ---------------- */

function debounce(fn, ms) {
  let t;
  return (...args) => {
    clearTimeout(t);
    t = setTimeout(() => fn(...args), ms);
  };
}

function slug(s) {
  return String(s).toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/(^-|-$)/g, "");
}

function escapeHtml(s) {
  return String(s ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
}
function escapeAttr(s) { return escapeHtml(s); }
function cssEscape(s) {
  return String(s).replace(/["\\]/g, "\\$&");
}

// footer timestamp
document.addEventListener("DOMContentLoaded", () => {
  const el = document.getElementById("footerUpdated");
  if (el) el.textContent = `Last updated ${new Date().toLocaleDateString("en-US", { month: "long", day: "numeric", year: "numeric" })}`;
});
