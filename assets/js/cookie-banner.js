function deleteGACookies() {
  const cookies = document.cookie.split(";");

  cookies.forEach(cookie => {
    const name = cookie.split("=")[0].trim();
    if (name.startsWith("_ga") || name === "_gid" || name === "_gat") {
      document.cookie = name + "=; expires=Thu, 01 Jan 1970 00:00:00 GMT; path=/";
    }
  });
}

document.addEventListener("DOMContentLoaded", function () {
  const resetBtn = document.getElementById("reset-cookie-options");
  const spacer = document.getElementById("cookie-spacer");
  const banner = document.getElementById("cookie-banner");
  const acceptBtn = document.getElementById("cookie-accept");
  const declineBtn = document.getElementById("cookie-decline");

  // Show banner if not yet decided
  if (!localStorage.getItem("cookieConsent")) {
    spacer.classList.remove("hidden");
    banner.classList.remove("hidden");
  }

  resetBtn.addEventListener("click", (e) => {
    e.preventDefault();
    localStorage.removeItem("cookieConsent");
    deleteGACookies();
    spacer.classList.remove("hidden");
    banner.classList.remove("hidden");
  });

  acceptBtn.addEventListener("click", () => {
    localStorage.setItem("cookieConsent", "accepted");
    // Enable Google Analytics
    gtag("consent", "update", {analytics_storage: "granted", ad_storage: "denied"});
    spacer.classList.add("hidden");
    banner.classList.add("hidden");
  });

  declineBtn.addEventListener("click", () => {
    localStorage.setItem("cookieConsent", "declined");
    gtag("consent", "update", {analytics_storage: "denied"});
    spacer.classList.add("hidden");
    banner.classList.add("hidden");
    deleteGACookies();
  });
});
