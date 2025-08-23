// Theme Toggle Functionality
function toggleTheme() {
  const currentTheme = document.body.getAttribute("data-theme");
  const newTheme = currentTheme === "dark" ? "light" : "dark";
  document.body.setAttribute("data-theme", newTheme);
  localStorage.setItem("theme", newTheme);

  const themeIcon = document.querySelector(".theme-icon");
  themeIcon.textContent = newTheme === "dark" ? "☀️" : "🌙";
}

// Initialize theme on page load
function initializeTheme() {
  const savedTheme = localStorage.getItem("theme");
  const prefersDark = window.matchMedia("(prefers-color-scheme: dark)").matches;
  const theme = savedTheme || (prefersDark ? "dark" : "light");
  document.body.setAttribute("data-theme", theme);

  const themeIcon = document.querySelector(".theme-icon");
  if (themeIcon) themeIcon.textContent = theme === "dark" ? "☀️" : "🌙";
}

// ===== API placeholders (CI will replace these before upload) =====
// Replace __VISITOR_API_URL__ and __CONTACT_API_URL__ in CI with real endpoints
const VISITOR_API_URL = "__VISITOR_API_URL__";
const CONTACT_API_URL = "__CONTACT_API_URL__";

// Visitor Logging (AWS Lambda Integration)
async function logVisitor() {
  if (!VISITOR_API_URL || VISITOR_API_URL.includes("__VISITOR_API_URL__")) {
    // Not yet configured
    return;
  }
  try {
    await fetch(VISITOR_API_URL, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        page: window.location.pathname,
        timestamp: new Date().toISOString()
      })
    });
  } catch (err) {
    console.error("Visitor logging failed:", err);
  }
}

// Contact Form Submission
async function handleFormSubmission(e) {
  e.preventDefault();

  const name = document.getElementById("name").value.trim();
  const email = document.getElementById("email").value.trim();
  const message = document.getElementById("message").value.trim();
  const referralCode = document.getElementById("referralCode").value.trim();

  if (!referralCode) {
    alert("Referral code is required.");
    return;
  }
  if (!name || !email || !message) {
    alert("Please fill in all fields.");
    return;
  }
  if (!CONTACT_API_URL || CONTACT_API_URL.includes("__CONTACT_API_URL__")) {
    alert("Contact endpoint not configured yet. Try again later.");
    return;
  }

  try {
    const response = await fetch(CONTACT_API_URL, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ name, email, message, referralCode })
    });

    const result = await response.json().catch(() => ({}));
    if (response.ok) {
      alert(result.message || "Message sent successfully!");
      document.getElementById("contactForm").reset();
    } else {
      alert(result.error || "Submission failed");
    }
  } catch (error) {
    console.error("Error:", error);
    alert("Something went wrong. Please try again later.");
  }
}

// Run on Load
document.addEventListener("DOMContentLoaded", function() {
  initializeTheme();
  logVisitor();

  const contactForm = document.getElementById("contactForm");
  if (contactForm) contactForm.addEventListener("submit", handleFormSubmission);
});
