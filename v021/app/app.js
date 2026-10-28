const store = window.POIDemoStore;
const screens = Array.from(document.querySelectorAll(".screen"));
const tabs = Array.from(document.querySelectorAll(".nav-tab"));
const pageTitle = document.getElementById("page-title");
const toast = document.getElementById("toast");
let toastTimer = null;
let recognitionTimer = null;

const titleMap = {
  upload: "上传医嘱",
  calendar: "干预日历",
  records: "病例与消息"
};

const statusMap = {
  pending: ["待执行", "gray"],
  completed: ["已完成", "mint"],
  paused: ["已暂缓", "gold"],
  overdue: ["已逾期", "red"],
  abnormal: ["异常反馈", "red"]
};

const kindMap = {
  daily: "日",
  education: "剧",
  records: "档",
  survey: "卷"
};

function showToast(message) {
  toast.textContent = message;
  toast.classList.remove("hidden");
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => toast.classList.add("hidden"), 2500);
}

function showScreen(name) {
  screens.forEach(screen => screen.classList.toggle("active", screen.id === `screen-${name}`));
  tabs.forEach(tab => tab.classList.toggle("active", tab.dataset.screen === name));
  pageTitle.textContent = titleMap[name];
  document.querySelector(".app-main").scrollTop = 0;
}

function uploadSteps(status) {
  const rank = {
    not_uploaded: 0,
    recognizing: 1,
    patient_review: 2,
    doctor_review: 3,
    active: 4
  }[status] || 0;
  const labels = ["上传", "识别", "核对", "审核", "生效"];
  return `<div class="workflow-steps">${labels
    .map((label, index) => `<span class="workflow-step ${index < rank ? "done" : index === rank ? "active" : ""}">${label}</span>`)
    .join("")}</div>`;
}

function renderUpload(state) {
  const panel = document.getElementById("upload-panel");
  const status = state.order.status;

  if (status === "not_uploaded") {
    panel.innerHTML = `
      <div class="upload-hero">
        <div class="upload-icon">＋</div>
        <h2>上传线下医嘱单</h2>
        <p>拍摄或选择医嘱资料。系统将模拟识别关键字段，并由你核对后提交医生审核。</p>
        <div class="upload-actions">
          <button class="primary-btn" data-action="upload-demo">使用演示医嘱</button>
          <button class="ghost-btn" data-action="upload-info">查看资料要求</button>
        </div>
      </div>
    `;
    return;
  }

  if (status === "recognizing") {
    panel.innerHTML = `
      ${uploadSteps(status)}
      <div class="status-card">
        <div class="loading">正在模拟识别医嘱字段…</div>
        <h3>请稍候</h3>
        <p>当前为演示识别，不会上传真实图片或调用真实 OCR。</p>
      </div>
    `;
    return;
  }

  if (status === "patient_review") {
    panel.innerHTML = `
      ${uploadSteps(status)}
      <div class="status-card recognition-card">
        <div class="recognition-head">
          <div>
            <span class="pill gold">模拟识别完成</span>
            <h3>请核对医嘱信息</h3>
            <p>如发现识别错误，正式版本应支持手工修订。</p>
          </div>
          <span class="status-label" style="color:var(--teal)">3 项高置信</span>
        </div>
        <div class="field-list">
          ${state.order.fields
            .map(field => `<div class="field-row"><span>${field.label}</span><strong>${field.value}</strong></div>`)
            .join("")}
        </div>
        <div class="recognition-actions">
          <button class="primary-btn" data-action="confirm-order">信息无误，提交审核</button>
          <button class="secondary-btn" data-action="reset-demo">重新上传</button>
        </div>
      </div>
    `;
    return;
  }

  if (status === "doctor_review") {
    panel.innerHTML = `
      ${uploadSteps(status)}
      <div class="status-card">
        <span class="pill gold">等待医生审核</span>
        <h3>医嘱已提交</h3>
        <p>患者端步骤已完成。请切换到医生端审核，并下发数字医嘱套。</p>
        <a class="primary-btn" href="../doctor/index.html">打开医生端 →</a>
      </div>
    `;
    return;
  }

  panel.innerHTML = `
    ${uploadSteps(status)}
    <div class="status-card">
      <span class="pill mint">电子医嘱已生效</span>
      <h3>${state.order.fields[1].value}</h3>
      <p>医生审核时间：${state.order.reviewedAt} · 原始图片与识别版本已归档。</p>
      <button class="primary-btn" data-screen="calendar">查看干预日历</button>
    </div>
  `;
}

function renderFollowup(state) {
  const target = document.getElementById("followup-summary");
  target.innerHTML = `
    <div class="followup-card">
      <div>
        <span class="pill blue">下次复诊</span>
        <h3>${state.patient.nextVisit} · 妇科内分泌门诊</h3>
        <p>复诊日期来自演示医嘱，不由药物用完时间自动推定。</p>
      </div>
      <div class="followup-date">11月<br>24日</div>
    </div>
  `;
}

function renderRecentMessages(state) {
  const target = document.getElementById("recent-messages");
  target.innerHTML = state.messages
    .slice(0, 3)
    .map(
      message => `
        <div class="message-preview">
          <span class="message-dot ${message.read ? "read" : ""}"></span>
          <div>
            <strong>${message.title}</strong>
            <p>${message.body}</p>
          </div>
        </div>
      `
    )
    .join("");
}

function renderTasks(state) {
  const summary = document.getElementById("task-summary");
  const list = document.getElementById("task-list");
  const completed = state.tasks.filter(task => task.status === "completed").length;
  const total = state.tasks.length;

  if (!total) {
    summary.innerHTML = `
      <div class="summary-card">
        <div><strong>0</strong><p>当前任务</p></div>
        <span class="pill gray">等待医嘱审核</span>
      </div>
    `;
    list.innerHTML = `
      <div class="empty-state">
        ${state.order.status === "doctor_review" ? "医嘱正在等待医生审核。审核通过后，任务会自动出现在这里。" : "上传并确认医嘱后，医生下发任务会显示在这里。"}
      </div>
    `;
    return;
  }

  summary.innerHTML = `
    <div class="summary-card">
      <div>
        <strong>${completed} / ${total}</strong>
        <p>已完成任务 · 来源：${state.tasks[0]?.source || "数字医嘱套"}</p>
      </div>
      <div class="summary-ring">${Math.round((completed / total) * 100)}%</div>
    </div>
  `;

  list.innerHTML = state.tasks
    .slice()
    .sort((a, b) => a.dueAt.localeCompare(b.dueAt))
    .map(task => {
      const [statusText, statusClass] = statusMap[task.status] || statusMap.pending;
      return `
        <article class="task-card">
          <div class="task-top">
            <span class="task-kind">${kindMap[task.kind] || "任"}</span>
            <div class="task-copy">
              <h3>${task.title}</h3>
              <p>截止 ${task.dueAt} · 来源：${task.source}</p>
            </div>
            <span class="pill ${statusClass}">${statusText}</span>
          </div>
          <div class="task-actions">
            ${
              task.status === "pending"
                ? `<button class="primary-btn" data-action="complete-task" data-task-id="${task.id}">标记完成</button>`
                : `<span class="status-label" style="color:var(--teal);padding:6px 0">${task.completedAt || "状态已记录"}</span>`
            }
            ${
              task.kind === "survey"
                ? `<a class="secondary-btn" href="../../survey.html" target="_blank" rel="noopener">打开问卷</a>`
                : ""
            }
          </div>
        </article>
      `;
    })
    .join("");
}

function renderRecords(state) {
  const summary = document.getElementById("record-summary");
  const completed = state.tasks.filter(task => task.status === "completed").length;
  summary.innerHTML = `
    <div class="record-card">
      <div class="record-top">
        <div>
          <span class="pill blue">${state.patient.id}</span>
          <h3>${state.patient.name} · ${state.patient.age} 岁</h3>
          <p>${state.patient.diagnosis}</p>
        </div>
        <span class="pill mint">${completed} 项已完成</span>
      </div>
    </div>
    <div class="record-card">
      <div class="record-top">
        <div>
          <span class="pill ${state.order.status === "active" ? "mint" : "gray"}">电子医嘱</span>
          <h3>${state.order.status === "not_uploaded" ? "尚未上传" : state.order.fields[1].value}</h3>
          <p>${state.order.status === "active" ? "已审核生效" : "当前状态以页面提示为准"}</p>
        </div>
      </div>
      <div class="record-file">
        <span>JPG</span>
        <div><strong>${state.order.fileName}</strong><small>模拟原始资料 · 仅用于界面演示</small></div>
      </div>
    </div>
  `;

  document.getElementById("message-list").innerHTML = state.messages
    .map(
      message => `
        <article class="message-card ${message.read ? "" : "unread"}">
          <div class="message-card-head">
            <strong>${message.title}</strong>
            <time>${message.time}</time>
          </div>
          <p>${message.body}</p>
          ${
            message.read
              ? ""
              : `<button class="link-btn" style="margin-top:8px" data-action="read-message" data-message-id="${message.id}">标为已读</button>`
          }
        </article>
      `
    )
    .join("");
}

function render() {
  const state = store.get();
  renderUpload(state);
  renderFollowup(state);
  renderRecentMessages(state);
  renderTasks(state);
  renderRecords(state);

  const unread = state.messages.filter(message => !message.read).length;
  const badge = document.getElementById("unread-badge");
  badge.textContent = String(unread);
  badge.classList.toggle("hidden", unread === 0);

  if (state.order.status === "recognizing" && !recognitionTimer) {
    recognitionTimer = setTimeout(() => {
      recognitionTimer = null;
      store.finishRecognition();
    }, 900);
  }
}

document.addEventListener("click", event => {
  const screenButton = event.target.closest("[data-screen]");
  if (screenButton) {
    showScreen(screenButton.dataset.screen);
    return;
  }

  const actionButton = event.target.closest("[data-action]");
  if (!actionButton) return;
  const action = actionButton.dataset.action;

  if (action === "upload-demo") {
    store.uploadDemoOrder();
    showToast("正在模拟识别演示医嘱");
  } else if (action === "upload-info") {
    showToast("正式版本可上传医嘱单、检查单或出院记录；本页不上传真实资料。");
  } else if (action === "confirm-order") {
    store.confirmOrder();
    showToast("已提交医生审核");
  } else if (action === "complete-task") {
    store.completeTask(actionButton.dataset.taskId);
    showToast("任务状态已更新");
  } else if (action === "read-message") {
    store.markMessageRead(actionButton.dataset.messageId);
  } else if (action === "reset-demo") {
    store.reset();
    showScreen("upload");
    showToast("演示数据已重置");
  }
});

window.addEventListener(store.eventName, render);
render();
