import { applyI18n, getLang, initLangToggle, t } from "./i18n.js";

const CLIENT_ORDER = ["windows", "macos", "android", "ios"];
const SERVER_ORDER = ["debian", "ubuntu", "centos", "rhel", "windows"];

/** Default partners when meta.partners is absent — fill real URLs in releases.json later. */
const DEFAULT_PARTNERS = [
  { name: "TradeMind", nameEn: "TradeMind", url: "#" },
  { name: "TM 开放平台", nameEn: "TM Open Platform", url: "#" },
];

const clientGrid = document.querySelector("[data-client-grid]");
const serverGrid = document.querySelector("[data-server-grid]");
const navToggle = document.querySelector("[data-nav-toggle]");
const siteNav = document.querySelector("[data-site-nav]");

/** @type {Record<string, unknown> | null} */
let releaseCache = null;

applyI18n(document, getLang());
initNav();
initHeaderScroll();
initReveal();
initLangToggle(() => {
  if (releaseCache) {
    renderClients(releaseCache.clients || {});
    renderServers(releaseCache.servers || {});
    applyMeta(releaseCache.meta || {});
  }
  bindCopyButtons(document.querySelector("[data-help-commands]"));
});
bindCopyButtons(document.querySelector("[data-help-commands]"));
loadReleases();

function initNav() {
  if (!navToggle || !siteNav) return;

  navToggle.addEventListener("click", () => {
    const open = siteNav.classList.toggle("is-open");
    navToggle.setAttribute("aria-expanded", String(open));
  });

  siteNav.querySelectorAll("a").forEach((link) => {
    link.addEventListener("click", () => {
      siteNav.classList.remove("is-open");
      navToggle.setAttribute("aria-expanded", "false");
    });
  });
}

function initHeaderScroll() {
  const header = document.querySelector(".site-header");
  if (!header) return;

  const sync = () => {
    header.classList.toggle("is-scrolled", window.scrollY > 12);
  };

  sync();
  window.addEventListener("scroll", sync, { passive: true });
}

function initReveal() {
  const items = document.querySelectorAll("[data-reveal]");
  if (!items.length) return;

  if (!("IntersectionObserver" in window)) {
    items.forEach((el) => el.classList.add("is-visible"));
    return;
  }

  const observer = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          entry.target.classList.add("is-visible");
          observer.unobserve(entry.target);
        }
      });
    },
    { threshold: 0.25, rootMargin: "0px 0px -8% 0px" }
  );

  items.forEach((el) => observer.observe(el));
}

async function loadReleases() {
  try {
    const res = await fetch(`${import.meta.env.BASE_URL}releases.json`, { cache: "no-cache" });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data = await res.json();
    releaseCache = data;
    applyMeta(data.meta || {});
    renderClients(data.clients || {});
    renderServers(data.servers || {});
  } catch (err) {
    console.error("Failed to load releases.json", err);
    applyMeta({});
    renderLoadError(clientGrid, t("dl.loadClientsError"));
    renderLoadError(serverGrid, t("dl.loadServersError"));
  }
}

/**
 * Apply configurable site URLs + partners from releases.json meta.
 * Keys: officialSite, termsUrl, privacyUrl, partners[{name,nameEn?,url}]
 */
function applyMeta(meta) {
  const termsUrl = meta.termsUrl || "/terms.html";
  const privacyUrl = meta.privacyUrl || "/privacy.html";

  document.querySelectorAll("[data-terms-link]").forEach((el) => {
    el.setAttribute("href", termsUrl);
  });
  document.querySelectorAll("[data-privacy-link]").forEach((el) => {
    el.setAttribute("href", privacyUrl);
  });

  // officialSite is documented for app settings / operators; expose on <html> for tooling.
  if (meta.officialSite) {
    document.documentElement.dataset.officialSite = String(meta.officialSite);
  }

  renderPartners(Array.isArray(meta.partners) && meta.partners.length ? meta.partners : DEFAULT_PARTNERS);
}

function renderPartners(partners) {
  const list = document.querySelector("[data-partner-list]");
  if (!list) return;

  const lang = getLang();
  list.innerHTML = partners
    .map((p) => {
      const label =
        lang === "en" ? p.nameEn || p.name || "" : p.name || p.nameEn || "";
      const url = p.url || "#";
      return `<li><a class="partner-link" href="${escapeAttr(url)}"${
        url === "#" ? "" : ' rel="noopener noreferrer"'
      }>${escapeHtml(label)}</a></li>`;
    })
    .join("");
}

function renderLoadError(container, message) {
  if (!container) return;
  container.innerHTML = `<p class="card-error" role="alert">${escapeHtml(message)}</p>`;
}

function renderClients(clients) {
  if (!clientGrid) return;

  const cards = CLIENT_ORDER.map((key) => {
    const item = clients[key];
    if (!item) {
      return unavailableCard(key, "client");
    }
    return clientCard(key, item);
  }).join("");

  clientGrid.innerHTML = cards;
}

function renderServers(servers) {
  if (!serverGrid) return;

  const blocks = SERVER_ORDER.map((key) => {
    const item = servers[key];
    if (!item) {
      return unavailableCard(key, "server");
    }
    return serverBlock(key, item);
  }).join("");

  serverGrid.innerHTML = blocks;
  bindCopyButtons(serverGrid);
}

function clientCard(key, item) {
  const label = item.label || key;
  const version = item.version || "—";
  const sha = item.sha256 || "—";
  const url = item.url || "";
  const status = item.status || "";
  const lang = getLang();
  const note =
    lang === "en" ? item.noteEn || item.note || "" : item.note || item.noteEn || "";
  const localOnly =
    status === "local_source_only" || status === "source_local" || status === "not_distributed";
  const skipped = status === "skipped_signing";
  const pending =
    !localOnly && !skipped && (status === "pending_upload" || !url);

  let actionHtml;
  if (localOnly) {
    actionHtml = `<span class="btn btn-ghost is-disabled" aria-disabled="true">${escapeHtml(t("dl.localSource"))}</span>`;
  } else if (skipped) {
    actionHtml = `<span class="btn btn-ghost is-disabled" aria-disabled="true">${escapeHtml(t("dl.skippedSigning"))}</span>`;
  } else if (pending) {
    actionHtml = `<span class="btn btn-ghost is-disabled" aria-disabled="true">${escapeHtml(t("dl.uploadPending"))}</span>`;
  } else {
    actionHtml = `<a class="btn btn-ghost" href="${escapeAttr(url)}" download>${escapeHtml(t("dl.download"))}</a>`;
  }

  const noteHtml =
    localOnly || skipped || pending
      ? `<p class="card-error">${escapeHtml(note || (localOnly ? t("dl.localSourceNote") : pending ? t("dl.pendingNote") : t("dl.skippedSigningNote")))}</p>`
      : note
        ? `<p class="distro-note">${escapeHtml(note)}</p>`
        : "";

  return `
    <article class="download-card" data-platform="${escapeAttr(key)}">
      <h3 class="card-platform">${escapeHtml(label)}</h3>
      <p class="card-version">${escapeHtml(t("dl.version"))} ${escapeHtml(version)}</p>
      <p class="card-checksum">
        <span>SHA256</span>
        ${escapeHtml(sha || (localOnly || skipped ? "—" : t("dl.shaPending")))}
      </p>
      <div class="card-actions">
        ${actionHtml}
      </div>
      ${noteHtml}
    </article>
  `;
}

function serverBlock(key, item) {
  const label = item.label || key;
  const version = item.version || "—";
  const sha = item.sha256 || t("dl.shaPending");
  const cmd = item.installCommand || t("dl.uploadPending");
  const url = item.url || "";
  const installScriptUrl = item.installScriptUrl || "";
  const win2012Url = item.win2012Url || "";
  const docsUrl = item.docsUrl || "";
  const note =
    getLang() === "en" ? item.noteEn || item.note || "" : item.note || item.noteEn || "";
  const hasAnyDownload = Boolean(url || installScriptUrl || win2012Url);
  const pending = item.status === "pending_upload" || !hasAnyDownload;
  const isWindows = key === "windows";

  const actions = [];
  if (pending) {
    actions.push(
      `<span class="btn btn-ghost is-disabled" aria-disabled="true">${escapeHtml(t("dl.uploadPending"))}</span>`
    );
  } else {
    if (installScriptUrl) {
      const scriptLabel = isWindows
        ? t("dl.downloadInstallPs1")
        : t("dl.downloadInstallScript");
      actions.push(
        `<a class="btn btn-ghost" href="${escapeAttr(installScriptUrl)}" download>${escapeHtml(scriptLabel)}</a>`
      );
    }
    if (url) {
      const pkgLabel = isWindows
        ? t("dl.downloadWinExe")
        : item.filename
          ? `${t("dl.download")} ${item.filename}`
          : t("dl.downloadPkg");
      actions.push(
        `<a class="btn btn-ghost" href="${escapeAttr(url)}" download>${escapeHtml(pkgLabel)}</a>`
      );
    }
    if (win2012Url) {
      actions.push(
        `<a class="btn btn-ghost" href="${escapeAttr(win2012Url)}" download>${escapeHtml(t("dl.downloadWin2012Exe"))}</a>`
      );
    }
    if (docsUrl) {
      actions.push(
        `<a class="btn btn-ghost" href="${escapeAttr(docsUrl)}" target="_blank" rel="noopener noreferrer">${escapeHtml(t("dl.downloadDocs"))}</a>`
      );
    }
  }

  const sameFolderHint = isWindows
    ? `<p class="distro-hint">${escapeHtml(t("dl.windowsSameFolder"))}</p>`
    : "";

  return `
    <article class="distro-block" data-distro="${escapeAttr(key)}">
      <h3>${escapeHtml(label)}</h3>
      <p class="distro-meta">${escapeHtml(t("dl.version"))} ${escapeHtml(version)}</p>
      <p class="checksum-line">SHA256 ${escapeHtml(sha)}</p>
      <div class="command-row">
        <code data-copy-source>${escapeHtml(cmd)}</code>
        <button class="btn btn-ghost copy-btn" type="button" data-copy ${pending ? "disabled" : ""}>${escapeHtml(t("dl.copy"))}</button>
      </div>
      ${sameFolderHint}
      <div class="card-actions">
        ${actions.join("\n        ")}
      </div>
      ${note ? `<p class="distro-note">${escapeHtml(note)}</p>` : ""}
    </article>
  `;
}

function unavailableCard(key, kind) {
  const msg = kind === "server" ? t("dl.serverUnavailable") : t("dl.clientUnavailable");
  return `
    <article class="download-card">
      <h3 class="card-platform">${escapeHtml(key)}</h3>
      <p class="card-version">${escapeHtml(t("dl.version"))} —</p>
      <p class="card-checksum"><span>SHA256</span>—</p>
      <p class="card-error">${escapeHtml(msg)}</p>
    </article>
  `;
}

function bindCopyButtons(root) {
  if (!root) return;
  root.querySelectorAll("[data-copy]").forEach((btn) => {
    if (btn.dataset.copyBound === "1") return;
    btn.dataset.copyBound = "1";
    btn.addEventListener("click", async () => {
      const row = btn.closest(".command-row");
      const source = row?.querySelector("[data-copy-source]");
      const text = source?.textContent?.trim() || "";
      if (!text) return;

      try {
        await navigator.clipboard.writeText(text);
        btn.textContent = t("dl.copied");
        btn.disabled = true;
        setTimeout(() => {
          btn.textContent = t("dl.copy");
          btn.disabled = false;
        }, 1600);
      } catch {
        btn.textContent = t("dl.copyFail");
        setTimeout(() => {
          btn.textContent = t("dl.copy");
        }, 1600);
      }
    });
  });
}

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function escapeAttr(value) {
  return escapeHtml(value).replaceAll("`", "&#96;");
}
