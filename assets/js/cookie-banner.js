document.addEventListener("DOMContentLoaded", function () {
  const banner = document.getElementById("cookie-banner");
  const acceptBtn = document.getElementById("cookie-accept");
  const declineBtn = document.getElementById("cookie-decline");

  // Show banner if not yet decided
  if (!localStorage.getItem("cookieConsent")) {
    banner.classList.remove("hidden");
  }

  acceptBtn.addEventListener("click", () => {
    localStorage.setItem("cookieConsent", "accepted");
    // Enable Google Analytics
    gtag("consent", "update", { analytics_storage: "granted" });
    banner.classList.add("hidden");
  });

  declineBtn.addEventListener("click", () => {
    localStorage.setItem("cookieConsent", "declined");
    gtag("consent", "update", { analytics_storage: "denied" });
    banner.classList.add("hidden");
  });
});
