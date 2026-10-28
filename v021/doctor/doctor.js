const store = window.POIDemoStore;
const views = Array.from(document.querySelectorAll(".view"));
const navItems = Array.from(document.querySelectorAll(".side-nav-item"));
const pageTitle = document.getElementById("page-title");
const toast = document.getElementById("toast");
let selectedPatient = "P001";
let toastTimer = null;

const titleMap = {
  patients: "随访患者目录",
  ordersets: "数字医嘱套",
  analytics: "随访数据大盘",
  operations: "业务处理大盘"
};

const orderStatusMap = {
  not_uploaded: ["资料待上传", "gray"],
  recognizing: ["模拟识别中", "blue"],
  patient_review: ["患者核对中", "gold"],
  doctor_review: ["待审核", "gold"],
  active: ["随访中", "mint"]
};

function showToast(message) {
  toast.textContent = message;
  toast.classList.remove("hidden");
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => toast.classList.add("hidden"), 2500);
}

function showView(name) {
  views.forEach(view => view.classList.toggle("active", view.id === `view-${name}`));
  navItems.forEach(item => item.classList.toggle("active", item.dataset.view === name));
  pageTitle.textContent = titleMap[name];
  window.scrollTo({ top: 0, behavior: "smooth" });
}

function patientStatus(state) {
  return orderStatusMap[state.order.status] || orderStatusMap.not_uploaded;
}

function renderPendingReview(state) {
  const target = document.getElementById("pending-review");
  if (state.order.status !== "doctor_review") {
    target.innerHTML = "";
    return;
  }
  target.innerHTML = `
    <div class="review-banner">
      <div>
        <span class="pill gold">待医生审核</span>
        <h2>王女士 · P001 提交了模拟医嘱</h2>
        <p>患者已完成字段核对。审核后将生成“POI 三个月随访（演示）”任务。</p>
      </div>
      <button class="primary-btn" data-action="approve-order">审核并下发医嘱套</button>
    </div>
  `;
}

function patientRows(state) {
  const [statusText, statusClass] = patientStatus(state);
  const rows = [
    {
      id: state.patient.id,
      name: state.patient.name,
      age: state.patient.age,
      nextVisit: state.patient.nextVisit,
      status: statusText,
      statusClass
    },
    ...state.queue.map(item => ({
      ...item,
      statusClass: item.status.includes("逾期") || item.status.includes("失访") ? "red" : "blue"
    }))
  ];

  const keyword = document.getElementById("patient-search").value.trim().toLowerCase();
  return rows.filter(
    item => !keyword || item.id.toLowerCase().includes(keyword) || item.name.toLowerCase().includes(keyword)
  );
}

function renderPatientList(state) {
  const list = document.getElementById("patient-list");
  const rows = patientRows(state);
  list.innerHTML = rows
    .map(
      item => `
        <button class="patient-row ${item.id === selectedPatient ? "selected" : ""}" data-patient-id="${item.id}">
          <div>
            <strong>${item.name} · ${item.id}</strong>
            <small>${item.age} 岁 · ${item.nextVisit ? `下次复诊 ${item.nextVisit}` : "暂无复诊日期"}</small>
          </div>
          <div class="row-meta"><span class="pill ${item.statusClass || "blue"}">${item.status}</span></div>
        </button>
      `
    )
    .join("");
}

function renderTaskMini(task) {
  const text = task.status === "completed" ? "已完成" : "待执行";
  const color = task.status === "completed" ? "var(--teal)" : "var(--gold)";
  return `<div class="task-mini"><span>${task.title}</span><b style="color:${color}">${text}</b></div>`;
}

function renderP001Detail(state) {
  const completed = state.tasks.filter(task => task.status === "completed").length;
  const total = state.tasks.length;
  const percentage = total ? Math.round((completed / total) * 100) : 0;
  const [statusText, statusClass] = patientStatus(state);

  return `
    <div class="detail-head">
      <div>
        <span class="pill blue">${state.patient.id}</span>
        <h2>${state.patient.name}</h2>
        <p>${state.patient.age} 岁 · ${state.patient.diagnosis}</p>
      </div>
      <span class="pill ${statusClass}">${statusText}</span>
    </div>
    <div class="double-view">
      <section class="sub-card">
        <h3>专病评估</h3>
        <p>近期症状趋势（演示）</p>
        <div class="mini-bars">
          <div class="mini-bar-row"><span>睡眠</span><div class="mini-bar-track"><span style="width:62%"></span></div><b>62</b></div>
          <div class="mini-bar-row"><span>压力</span><div class="mini-bar-track"><span style="width:54%"></span></div><b>中</b></div>
          <div class="mini-bar-row"><span>情绪</span><div class="mini-bar-track"><span style="width:72%"></span></div><b>稳</b></div>
        </div>
      </section>
      <section class="sub-card">
        <h3>医嘱执行</h3>
        <p>${completed} / ${total} 项完成 · ${percentage}%</p>
        <div class="task-mini-list">
          ${state.tasks.length ? state.tasks.slice(0, 4).map(renderTaskMini).join("") : `<span class="muted">等待医嘱审核后生成任务</span>`}
        </div>
      </section>
    </div>
    <div class="detail-actions">
      ${
        state.order.status === "doctor_review"
          ? `<button class="primary-btn" data-action="approve-order">审核并生成任务</button>`
          : `<span class="pill ${state.order.status === "active" ? "mint" : "gray"}">医嘱状态：${statusText}</span>`
      }
      <a class="secondary-btn" href="../app/index.html">打开患者端 →</a>
    </div>
  `;
}

function renderOtherDetail(id, state) {
  const patient = state.queue.find(item => item.id === id);
  if (!patient) return renderP001Detail(state);
  return `
    <div class="detail-head">
      <div>
        <span class="pill gray">${patient.id}</span>
        <h2>${patient.name}</h2>
        <p>${patient.age} 岁 · ${patient.status}</p>
      </div>
      <span class="pill blue">模拟档案</span>
    </div>
    <div class="double-view">
      <section class="sub-card">
        <h3>专病评估</h3>
        <p>该患者为列表氛围数据，暂不提供联动详情。</p>
      </section>
      <section class="sub-card">
        <h3>医嘱执行</h3>
        <p>可在 V0.2 后续版本接入完整患者档案。</p>
      </section>
    </div>
  `;
}

function renderPatientDetail(state) {
  const target = document.getElementById("patient-detail");
  target.innerHTML = selectedPatient === "P001" ? renderP001Detail(state) : renderOtherDetail(selectedPatient, state);
}

function renderTemplates(state) {
  const target = document.getElementById("template-list");
  target.innerHTML = state.templates
    .map(
      template => `
        <article class="panel template-card">
          <div class="template-head">
            <div>
              <span class="pill blue">标准任务模板</span>
              <h3>${template.name}</h3>
              <p>${template.description}</p>
            </div>
            <span class="pill gold">演示</span>
          </div>
          <ul class="template-task-list">
            ${template.tasks
              .map(
                task => `
                  <li>
                    <span>${task.title}</span>
                    <b style="color:var(--muted)">第 ${task.offset + 1} 天</b>
                  </li>
                `
              )
              .join("")}
          </ul>
          <div class="template-footer">
            <span class="muted">${template.duration}</span>
            <button class="primary-btn" data-action="apply-template" data-template-id="${template.id}" ${state.order.status === "active" ? "" : "disabled style=\"opacity:.45\""}>应用到演示患者</button>
          </div>
        </article>
      `
    )
    .join("");
}

function renderChart(targetId, data) {
  const max = Math.max(...data.map(item => item.value));
  document.getElementById(targetId).innerHTML = data
    .map(
      item => `
        <div class="bar-row">
          <span>${item.label}</span>
          <div class="bar-track"><span style="width:${(item.value / max) * 100}%"></span></div>
          <strong>${item.value}</strong>
        </div>
      `
    )
    .join("");
}

function renderAnalytics(state) {
  const completed = state.tasks.filter(task => task.status === "completed").length;
  const tasks = state.tasks.length;
  const execution = tasks ? `${Math.round((completed / tasks) * 100)}%` : "待生成";
  document.getElementById("metric-grid").innerHTML = `
    <article class="metric-card"><span>累计入组</span><strong>${state.analytics.enrolled}</strong><small>演示队列</small></article>
    <article class="metric-card"><span>在管患者</span><strong>${state.analytics.active}</strong><small>演示数据</small></article>
    <article class="metric-card"><span>P001 任务完成</span><strong>${completed}/${tasks || 0}</strong><small>实时联动</small></article>
    <article class="metric-card"><span>P001 执行率</span><strong>${execution}</strong><small>任务完成率，非临床疗效</small></article>
  `;
  renderChart("followup-chart", state.analytics.followupDepth);
  renderChart("age-chart", state.analytics.ageGroups);
}

function renderOperations(state) {
  const reviewQueue = document.getElementById("review-queue");
  const pending = state.order.status === "doctor_review";
  reviewQueue.innerHTML = pending
    ? `
      <div class="operation-row">
        <div><strong>王女士 · P001</strong><span>模拟医嘱待审核</span></div>
        <button class="primary-btn" data-action="approve-order">审核</button>
      </div>
    `
    : `<div class="operation-empty">${state.order.status === "active" ? "P001 医嘱已审核生效。" : "当前没有待审核医嘱。"}</div>`;

  const overdue = state.tasks.filter(task => task.status === "overdue").length;
  document.getElementById("operation-count").textContent = `${(pending ? 1 : 0) + overdue + 1} 项待处理`;
}

function render() {
  const state = store.get();
  renderPendingReview(state);
  renderPatientList(state);
  renderPatientDetail(state);
  renderTemplates(state);
  renderAnalytics(state);
  renderOperations(state);
}

document.addEventListener("click", event => {
  const nav = event.target.closest("[data-view]");
  if (nav) {
    showView(nav.dataset.view);
    return;
  }

  const patient = event.target.closest("[data-patient-id]");
  if (patient) {
    selectedPatient = patient.dataset.patientId;
    render();
    return;
  }

  const actionButton = event.target.closest("[data-action]");
  if (!actionButton) return;
  const action = actionButton.dataset.action;

  if (action === "approve-order") {
    store.approveOrder("TPL-POI-3M");
    showToast("审核通过，已生成四项演示任务");
  } else if (action === "apply-template") {
    store.applyTemplate(actionButton.dataset.templateId);
    showToast("已将剩余模板任务应用到演示患者");
  } else if (action === "focus-search") {
    document.getElementById("patient-search").focus();
  } else if (action === "reset-demo") {
    store.reset();
    selectedPatient = "P001";
    showView("patients");
    showToast("演示数据已重置");
  }
});

document.getElementById("patient-search").addEventListener("input", () => render());
window.addEventListener(store.eventName, render);
render();
