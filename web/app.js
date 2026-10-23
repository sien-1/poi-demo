const navButtons = Array.from(document.querySelectorAll(".nav-item"));
const views = Array.from(document.querySelectorAll(".view"));
const roleButtons = Array.from(document.querySelectorAll(".role-btn"));
const pageTitle = document.getElementById("page-title");
const toast = document.getElementById("toast");

const titleMap = {
  overview: "总览",
  risk: "风险评估",
  followup: "随访复诊",
  education: "健康教育",
  monitoring: "健康监测",
  medication: "用药与补剂",
  doctor: "医生工作台"
};

let toastTimer = null;

function showView(viewName) {
  views.forEach(view => {
    view.classList.toggle("active", view.id === "view-" + viewName);
  });
  navButtons.forEach(button => {
    button.classList.toggle("active", button.dataset.view === viewName);
  });
  pageTitle.textContent = titleMap[viewName] || "总览";
}

function showToast(message) {
  toast.textContent = message;
  toast.classList.remove("hidden");
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => toast.classList.add("hidden"), 2600);
}

navButtons.forEach(button => {
  button.addEventListener("click", () => {
    showView(button.dataset.view);
    window.scrollTo({ top: 0, behavior: "smooth" });
  });
});

roleButtons.forEach(button => {
  button.addEventListener("click", () => {
    roleButtons.forEach(item => item.classList.toggle("active", item === button));
    if (button.dataset.role === "doctor") {
      showView("doctor");
    } else {
      showView("overview");
    }
  });
});

document.querySelectorAll(".demo-action").forEach(button => {
  button.addEventListener("click", () => {
    showToast(button.dataset.message || "功能原型：后续版本实现");
  });
});

showView("overview");
