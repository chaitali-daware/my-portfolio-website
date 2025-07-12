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
async function logVisitor() {
  try {
    await fetch("https://297o1qpe51.execute-api.ap-south-1.amazonaws.com/prod/visit", {
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
    alert("❗ Referral code is required.");
    return;
  }

  if (!name || !email || !message) {
    alert("❗ Please fill in all fields.");
    return;
  }

  try {
    const response = await fetch("https://ch5ycgvnr0.execute-api.ap-south-1.amazonaws.com/prod/contact", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ name, email, message, referralCode })
    });

    const result = await response.json();
    alert(`✅ ${result.message}`);
    document.getElementById("contactForm").reset();
  } catch (error) {
    console.error("Error:", error);
    alert("❌ Something went wrong. Please try again later.");
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
