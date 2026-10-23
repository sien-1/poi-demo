const tabs = Array.from(document.querySelectorAll(".tab"));
const screens = Array.from(document.querySelectorAll(".screen"));
const toast = document.getElementById("toast");

let toastTimer = null;

function showScreen(name) {
  screens.forEach(screen => {
    screen.classList.toggle("active", screen.id === "screen-" + name);
  });
  tabs.forEach(tab => {
    tab.classList.toggle("active", tab.dataset.screen === name);
  });
  document.querySelector(".app-main").scrollTop = 0;
}

function showToast(message) {
  toast.textContent = message;
  toast.classList.remove("hidden");
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => toast.classList.add("hidden"), 2400);
}

document.querySelectorAll("[data-screen]").forEach(button => {
  button.addEventListener("click", () => showScreen(button.dataset.screen));
});

document.querySelectorAll(".demo-action").forEach(button => {
  button.addEventListener("click", () => {
    showToast(button.dataset.message || "功能原型：后续版本实现");
  });
});

showScreen("home");
