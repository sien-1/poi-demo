(function () {
  const STORAGE_KEY = "poi-v021-demo-v1";
  const CHANGE_EVENT = "poi-demo-store-change";

  const baseState = {
    version: "V0.2.1",
    demoDate: "2026-11-01",
    patient: {
      id: "P001",
      name: "王女士",
      age: 32,
      diagnosis: "POI 长期随访（演示）",
      nextVisit: "2026-11-24",
      phone: "138****0000"
    },
    order: {
      id: "ORD-20261101-01",
      status: "not_uploaded",
      fileName: "演示医嘱单.jpg",
      uploadedAt: "",
      reviewedAt: "",
      fields: [
        { label: "开具日期", value: "2026-11-01", confidence: "高" },
        { label: "管理项目", value: "POI 长期随访（演示）", confidence: "高" },
        { label: "执行频次", value: "每日记录 · 每月评估", confidence: "高" },
        { label: "开始日期", value: "2026-11-01", confidence: "高" },
        { label: "结束日期", value: "2027-01-31", confidence: "中" },
        { label: "复查项目", value: "专病量表与症状记录", confidence: "高" },
        { label: "复诊时间", value: "2026-11-24", confidence: "高" }
      ]
    },
    tasks: [],
    messages: [
      {
        id: "MSG-001",
        type: "system",
        title: "欢迎进入演示环境",
        body: "当前患者、医嘱、日期与任务均为模拟数据。",
        time: "2026-11-01 08:00",
        read: false
      }
    ],
    templates: [
      {
        id: "TPL-POI-3M",
        name: "POI 三个月随访（演示）",
        description: "覆盖执行记录、科普学习、复诊准备与专病量表。",
        duration: "2026-11-01 至 2027-01-31",
        tasks: [
          { title: "记录今日执行情况", kind: "daily", offset: 0 },
          { title: "观看生殖健康科普短剧第1集", kind: "education", offset: 7 },
          { title: "回顾并准备近期检查资料", kind: "records", offset: 16 },
          { title: "填写 POI 专病随访问卷", kind: "survey", offset: 29 }
        ]
      }
    ],
    queue: [
      { id: "P002", name: "李女士", age: 29, nextVisit: "2026-11-05", status: "待复诊" },
      { id: "P003", name: "张女士", age: 35, nextVisit: "2026-11-08", status: "随访中" },
      { id: "P004", name: "陈女士", age: 38, nextVisit: "2026-11-12", status: "任务逾期" },
      { id: "P005", name: "赵女士", age: 31, nextVisit: "", status: "失访待联系" }
    ],
    analytics: {
      enrolled: 128,
      active: 113,
      exited: 9,
      lost: 6,
      followupDepth: [
        { label: "1 次", value: 38 },
        { label: "2 次", value: 31 },
        { label: "3 次", value: 24 },
        { label: "4–9 次", value: 29 },
        { label: "≥10 次", value: 6 }
      ],
      ageGroups: [
        { label: "18–25", value: 18 },
        { label: "26–30", value: 39 },
        { label: "31–35", value: 45 },
        { label: "36–40", value: 26 }
      ]
    }
  };

  function clone(value) {
    return JSON.parse(JSON.stringify(value));
  }

  function read() {
    try {
      const saved = localStorage.getItem(STORAGE_KEY);
      if (!saved) return clone(baseState);
      return { ...clone(baseState), ...JSON.parse(saved) };
    } catch (error) {
      console.warn("Unable to read demo state", error);
      return clone(baseState);
    }
  }

  function emit(state) {
    window.dispatchEvent(new CustomEvent(CHANGE_EVENT, { detail: state }));
  }

  function write(state) {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
    emit(state);
  }

  function update(mutator) {
    const state = read();
    mutator(state);
    write(state);
    return state;
  }

  function reset() {
    localStorage.removeItem(STORAGE_KEY);
    const state = read();
    emit(state);
    return state;
  }

  function addMessage(state, title, body) {
    state.messages.unshift({
      id: "MSG-" + Date.now(),
      type: "system",
      title,
      body,
      time: `${state.demoDate} ${new Date().toTimeString().slice(0, 5)}`,
      read: false
    });
  }

  function addDays(dateString, days) {
    const date = new Date(dateString + "T00:00:00");
    date.setDate(date.getDate() + days);
    return date.toISOString().slice(0, 10);
  }

  function buildTasks(state, template) {
    return template.tasks.map((task, index) => ({
      id: `TASK-${Date.now()}-${index}`,
      patientId: state.patient.id,
      title: task.title,
      kind: task.kind,
      source: template.name,
      dueAt: addDays(state.demoDate, task.offset),
      status: "pending",
      completedAt: ""
    }));
  }

  function uploadDemoOrder() {
    return update(state => {
      if (state.order.status !== "not_uploaded") return;
      state.order.status = "recognizing";
      state.order.uploadedAt = `${state.demoDate} 09:10`;
    });
  }

  function finishRecognition() {
    return update(state => {
      if (state.order.status !== "recognizing") return;
      state.order.status = "patient_review";
    });
  }

  function confirmOrder() {
    return update(state => {
      if (state.order.status !== "patient_review") return;
      state.order.status = "doctor_review";
      addMessage(state, "医嘱已提交审核", "患者已核对模拟识别结果，等待医生审核。");
    });
  }

  function approveOrder(templateId = "TPL-POI-3M") {
    return update(state => {
      if (state.order.status !== "doctor_review") return;
      const template = state.templates.find(item => item.id === templateId) || state.templates[0];
      state.order.status = "active";
      state.order.reviewedAt = `${state.demoDate} 10:20`;
      state.tasks = buildTasks(state, template);
      addMessage(state, "医生已审核并下发任务", `已应用“${template.name}”，请按日历执行。`);
    });
  }

  function completeTask(taskId, status = "completed") {
    return update(state => {
      const task = state.tasks.find(item => item.id === taskId);
      if (!task) return;
      task.status = status;
      task.completedAt = `${state.demoDate} ${new Date().toTimeString().slice(0, 5)}`;
      addMessage(state, "任务状态已更新", `“${task.title}”已标记为${status === "completed" ? "完成" : "暂缓"}。`);
    });
  }

  function markMessageRead(messageId) {
    return update(state => {
      const message = state.messages.find(item => item.id === messageId);
      if (message) message.read = true;
    });
  }

  function applyTemplate(templateId) {
    return update(state => {
      if (state.order.status !== "active") return;
      const template = state.templates.find(item => item.id === templateId);
      if (!template) return;
      const existing = new Set(state.tasks.map(item => item.title));
      template.tasks.forEach(task => {
        if (!existing.has(task.title)) {
          state.tasks.push(
            ...buildTasks(state, {
              ...template,
              tasks: [task]
            })
          );
        }
      });
      addMessage(state, "医生新增了随访任务", `已应用“${template.name}”中的剩余任务。`);
    });
  }

  window.addEventListener("storage", event => {
    if (event.key === STORAGE_KEY) emit(read());
  });

  window.POIDemoStore = {
    eventName: CHANGE_EVENT,
    get: read,
    update,
    reset,
    uploadDemoOrder,
    finishRecognition,
    confirmOrder,
    approveOrder,
    completeTask,
    markMessageRead,
    applyTemplate,
    addDays
  };
})();
