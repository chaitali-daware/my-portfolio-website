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
  if (themeIcon) {
    themeIcon.textContent = theme === "dark" ? "☀️" : "🌙";
  }
}

// Visitor Logging (AWS Lambda Integration)
// __VISITOR_API_URL__ will be replaced by CI with full URL like https://.../visit
async function logVisitor() {
  try {
    await fetch("__VISITOR_API_URL__", {
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

  try {
    const response = await fetch("__CONTACT_API_URL__", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ name, email, message, referralCode })
    });

    const result = await response.json();
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
  if (contactForm) {
    contactForm.addEventListener("submit", handleFormSubmission);
  }
});
