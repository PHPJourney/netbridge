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
  const termsUrl = meta.termsUrl || `${import.meta.env.BASE_URL}terms.html`;
  const privacyUrl = meta.privacyUrl || `${import.meta.env.BASE_URL}privacy.html`;

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
  const portableUrl = item.portableUrl || "";
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
    const isWindows = key === "windows";
    const primaryLabel = isWindows ? t("dl.downloadClientWinSetup") : t("dl.download");
    const parts = [
      `<a class="btn btn-ghost" href="${escapeAttr(url)}" download>${escapeHtml(primaryLabel)}</a>`,
    ];
    if (isWindows && portableUrl) {
      parts.push(
        `<a class="btn btn-ghost" href="${escapeAttr(portableUrl)}" download>${escapeHtml(t("dl.downloadWinPortable"))}</a>`
      );
    }
    actionHtml = parts.join("\n        ");
  }

  const isWindowsClient = key === "windows" && !localOnly && !skipped;
  const noteHtml =
    localOnly || skipped || pending
      ? `<p class="card-error">${escapeHtml(note || (localOnly ? t("dl.localSourceNote") : pending ? t("dl.pendingNote") : t("dl.skippedSigningNote")))}</p>`
      : note
        ? `<p class="distro-note">${escapeHtml(note)}</p>`
        : "";
  const winClientHint = isWindowsClient
    ? `<p class="distro-hint">${escapeHtml(t("dl.windowsClientHint"))}</p>`
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
      ${winClientHint}
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
  const setupUrl = item.setupUrl || "";
  const installScriptUrl = item.installScriptUrl || "";
  const win2012Url = item.win2012Url || "";
  const docsUrl = item.docsUrl || "";
  const note =
    getLang() === "en" ? item.noteEn || item.note || "" : item.note || item.noteEn || "";
  const hasAnyDownload = Boolean(url || setupUrl || installScriptUrl || win2012Url);
  const pending = item.status === "pending_upload" || !hasAnyDownload;
  const isWindows = key === "windows";

  if (isWindows) {
    return windowsServerBlock({
      label,
      version,
      sha,
      cmd,
      setupUrl,
      url,
      win2012Url,
      installScriptUrl,
      docsUrl,
      note,
      pending,
    });
  }

  const actions = [];
  const secondaryLinks = [];
  if (pending) {
    actions.push(
      `<span class="btn btn-ghost is-disabled" aria-disabled="true">${escapeHtml(t("dl.uploadPending"))}</span>`
    );
  } else {
    if (url) {
      const pkgLabel = item.filename
        ? `${t("dl.download")} ${item.filename}`
        : t("dl.downloadPkg");
      actions.push(
        `<a class="btn btn-ghost btn-compact" href="${escapeAttr(url)}" download>${escapeHtml(pkgLabel)}</a>`
      );
    }
    if (installScriptUrl) {
      secondaryLinks.push(
        `<a class="text-link" href="${escapeAttr(installScriptUrl)}" download>${escapeHtml(t("dl.downloadInstallScript"))}</a>`
      );
    }
  }

  return `
    <article class="distro-block" data-distro="${escapeAttr(key)}">
      <h3>${escapeHtml(label)}</h3>
      <p class="distro-meta">${escapeHtml(t("dl.version"))} ${escapeHtml(version)}</p>
      <p class="checksum-line">SHA256 ${escapeHtml(sha)}</p>
      <div class="command-row">
        <code data-copy-source>${escapeHtml(cmd)}</code>
        <button class="btn btn-ghost copy-btn" type="button" data-copy ${pending ? "disabled" : ""}>${escapeHtml(t("dl.copy"))}</button>
      </div>
      ${
        actions.length
          ? `<div class="card-actions">
        ${actions.join("\n        ")}
      </div>`
          : ""
      }
      ${
        secondaryLinks.length
          ? `<p class="card-secondary-links">${secondaryLinks.join(" · ")}</p>`
          : ""
      }
      ${note ? `<p class="distro-note">${escapeHtml(note)}</p>` : ""}
    </article>
  `;
}

/**
 * Windows Server card: Setup.exe primary; PowerShell one-liner + manual links under Advanced.
 */
function windowsServerBlock({
  label,
  version,
  sha,
  cmd,
  setupUrl,
  url,
  win2012Url,
  installScriptUrl,
  docsUrl,
  note,
  pending,
}) {
  let primaryHtml;
  if (pending || !setupUrl) {
    primaryHtml = `<span class="btn btn-primary btn-block is-disabled" aria-disabled="true">${escapeHtml(t("dl.uploadPending"))}</span>`;
  } else {
    primaryHtml = `<a class="btn btn-primary btn-block" href="${escapeAttr(setupUrl)}" download>${escapeHtml(t("dl.downloadWinSetup"))}</a>`;
  }

  const advLinks = [];
  if (installScriptUrl) {
    advLinks.push(
      `<a class="text-link" href="${escapeAttr(installScriptUrl)}" download>${escapeHtml(t("dl.linkInstallPs1"))}</a>`
    );
  }
  if (win2012Url) {
    advLinks.push(
      `<a class="text-link" href="${escapeAttr(win2012Url)}" download>${escapeHtml(t("dl.linkWin2012Exe"))}</a>`
    );
  }
  if (url) {
    advLinks.push(
      `<a class="text-link" href="${escapeAttr(url)}" download>${escapeHtml(t("dl.linkWinExe"))}</a>`
    );
  }
  if (docsUrl) {
    advLinks.push(
      `<a class="text-link" href="${escapeAttr(docsUrl)}" target="_blank" rel="noopener noreferrer">${escapeHtml(t("dl.linkWindowsMd"))}</a>`
    );
  }

  const win2012Steps =
    win2012Url
      ? `<p class="distro-advanced-lead">${escapeHtml(t("dl.windows2012Lead"))}</p>
        <ol class="distro-steps">
          <li>${escapeHtml(t("dl.windows2012Step1"))}</li>
          <li>${
            installScriptUrl
              ? `<a class="text-link" href="${escapeAttr(installScriptUrl)}" download>${escapeHtml(t("dl.linkInstallPs1"))}</a>`
              : escapeHtml(t("dl.linkInstallPs1"))
          } ${escapeHtml(t("dl.windows2012Step2Tail"))}</li>
          <li>${escapeHtml(t("dl.windows2012Step3"))}</li>
        </ol>
        <div class="card-actions">
          <a class="btn btn-ghost btn-block" href="${escapeAttr(win2012Url)}" download>${escapeHtml(t("dl.downloadWin2012Exe"))}</a>
          ${
            installScriptUrl
              ? `<a class="btn btn-ghost btn-block" href="${escapeAttr(installScriptUrl)}" download>${escapeHtml(t("dl.downloadInstallPs1"))}</a>`
              : ""
          }
        </div>
        <div class="command-row">
          <code data-copy-source>${escapeHtml(t("dl.windows2012Cmd"))}</code>
          <button class="btn btn-ghost copy-btn" type="button" data-copy ${pending ? "disabled" : ""}>${escapeHtml(t("dl.copy"))}</button>
        </div>
        <p class="distro-hint">${escapeHtml(t("dl.windowsSameFolder"))}</p>`
      : "";

  return `
    <article class="distro-block distro-block--windows" data-distro="windows">
      <h3>${escapeHtml(label)}</h3>
      <p class="distro-meta">${escapeHtml(t("dl.version"))} ${escapeHtml(version)}</p>
      <p class="checksum-line">SHA256 ${escapeHtml(sha)}</p>
      <p class="distro-callout" role="note">${escapeHtml(t("dl.windows2012Banner"))}</p>
      <div class="card-actions card-actions--primary">
        ${primaryHtml}
      </div>
      <p class="distro-hint">${escapeHtml(t("dl.windowsSetupHint"))}</p>
      <details class="distro-advanced"${win2012Url ? " open" : ""}>
        <summary>${escapeHtml(t("dl.windowsAdvanced"))}</summary>
        ${win2012Steps}
        <p class="distro-advanced-lead">${escapeHtml(t("dl.windowsBootstrapHint"))}</p>
        <div class="command-row">
          <code data-copy-source>${escapeHtml(cmd)}</code>
          <button class="btn btn-ghost copy-btn" type="button" data-copy ${pending ? "disabled" : ""}>${escapeHtml(t("dl.copy"))}</button>
        </div>
        ${
          advLinks.length
            ? `<p class="card-secondary-links">${advLinks.join(" · ")}</p>`
            : ""
        }
      </details>
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
