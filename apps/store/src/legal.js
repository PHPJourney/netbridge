import { applyI18n, getLang, initLangToggle } from "./i18n.js";

applyI18n(document, getLang());
initLangToggle();
initHeaderScroll();

loadLegalMeta();

function initHeaderScroll() {
  const header = document.querySelector(".site-header");
  if (!header) return;

  const sync = () => {
    header.classList.toggle("is-scrolled", window.scrollY > 12);
  };

  sync();
  window.addEventListener("scroll", sync, { passive: true });
}

async function loadLegalMeta() {
  try {
    const res = await fetch(`${import.meta.env.BASE_URL}releases.json`, { cache: "no-cache" });
    if (!res.ok) return;
    const data = await res.json();
    const meta = data.meta || {};
    const termsUrl = meta.termsUrl || `${import.meta.env.BASE_URL}terms.html`;
    const privacyUrl = meta.privacyUrl || `${import.meta.env.BASE_URL}privacy.html`;
    document.querySelectorAll("[data-terms-link]").forEach((el) => {
      el.setAttribute("href", termsUrl);
    });
    document.querySelectorAll("[data-privacy-link]").forEach((el) => {
      el.setAttribute("href", privacyUrl);
    });
    if (meta.officialSite) {
      document.documentElement.dataset.officialSite = String(meta.officialSite);
    }
  } catch {
    /* keep defaults */
  }
}
