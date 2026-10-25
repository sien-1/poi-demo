// 问卷链接已接入腾讯文档。若后续链接或版本调整，只需修改对应项目的 name / url。
const surveys = [
  {
    category: "研究完整版",
    name: "POI 综合问卷（研究完整版）",
    description: "整合基本信息、病史、月经与症状及专项量表；当前为二维码演示页，不保存答案。",
    time: "完整版入口",
    tag: "完整版草稿",
    actionLabel: "打开完整版",
    url: "survey-full.html"
  },
  {
    category: "认知功能",
    name: "MMSE 简易版",
    description: "认知功能筛查；具体施测方式与版本按研究流程执行。",
    time: "约 5–10 分钟",
    url: "https://wj.qq.com/s2/28334522/v3l1/"
  },
  {
    category: "认知功能",
    name: "MoCA",
    description: "蒙特利尔认知评估；与 MMSE 存在用途重叠，按研究方案选用。",
    time: "约 10–15 分钟",
    url: "https://wj.qq.com/s2/28334543/rjs1/"
  },
  {
    category: "骨质疏松",
    name: "IOF 一分钟",
    description: "骨质疏松风险快速筛查；适合初筛或随访提醒。",
    time: "约 1 分钟",
    url: "https://wj.qq.com/s2/28334272/3ldn/"
  },
  {
    category: "骨质疏松",
    name: "IOF 2022 指南版",
    description: "依据 IOF 2022 指南的骨质疏松风险评估。",
    time: "约 5–10 分钟",
    url: "https://wj.qq.com/s2/28334560/u4kk/"
  },
  {
    category: "骨质疏松",
    name: "OSTA",
    description: "骨质疏松自我筛查工具；与 IOF/FRAX 用途不同，按方案选择。",
    time: "约 3–5 分钟",
    url: "https://wj.qq.com/s2/28334572/3rqq/"
  },
  {
    category: "骨质疏松",
    name: "FRAX",
    description: "骨折风险评估工具；需按研究要求录入相应参数。",
    time: "约 5–10 分钟",
    url: "https://wj.qq.com/s2/28334588/2dvx/"
  },
  {
    category: "Kupperman",
    name: "Kupperman 原版 11 项",
    description: "围绝经期症状评估；与 13 项版本二选一，按研究方案执行。",
    time: "约 3–5 分钟",
    url: "https://wj.qq.com/s2/28334591/qoc4/"
  },
  {
    category: "Kupperman",
    name: "Kupperman 13 项",
    description: "围绝经期症状评估；与原版 11 项二选一，按研究方案执行。",
    time: "约 3–5 分钟",
    url: "https://wj.qq.com/s2/28334597/2jxi/"
  },
  {
    category: "睡眠与压力",
    name: "匹兹堡睡眠质量指数（PSQI）",
    description: "评估近一个月的睡眠质量与睡眠相关问题。",
    time: "约 5–10 分钟",
    url: "https://wj.qq.com/s2/28334606/2li8/"
  },
  {
    category: "睡眠与压力",
    name: "CPSS 压力知觉量表",
    description: "评估近期主观压力水平。",
    time: "约 3–5 分钟",
    url: "https://wj.qq.com/s2/28334614/ifzg/"
  },
  {
    category: "睡眠与压力",
    name: "阿森斯失眠量表（AIS）",
    description: "睡眠困难及日间影响的自评；与 PSQI 可按研究时间点选择。",
    time: "约 3–5 分钟",
    url: "https://wj.qq.com/s2/28334644/ovjj/"
  },
  {
    category: "心理与情绪",
    name: "汉密尔顿抑郁量表（HAMD）",
    description: "抑郁相关症状评估，需由研究团队确认施测方式。",
    time: "约 10–15 分钟",
    url: "https://wj.qq.com/s2/28334639/ad37/"
  },
  {
    category: "心理与情绪",
    name: "汉密尔顿焦虑量表（HAMA）",
    description: "焦虑相关症状评估，结果需结合临床判断。",
    time: "约 10–15 分钟",
    url: "https://wj.qq.com/s2/28334627/dmoy/"
  },
  {
    category: "心理与情绪",
    name: "贝克自杀意念量表（BSI-CV）",
    description: "涉及敏感心理条目；如出现明显不适，请暂停并联系研究团队。",
    time: "约 5–10 分钟",
    url: "https://wj.qq.com/s2/28334621/e47o/"
  },
  {
    category: "症状与生活质量",
    name: "痛经症状量表（CMSS）",
    description: "记录痛经相关症状及严重程度。",
    time: "约 3–5 分钟",
    url: "https://wj.qq.com/s2/28334652/smnq/"
  },
  {
    category: "症状与生活质量",
    name: "围绝经期生存质量量表（MENQOL）",
    description: "评估近期生活质量及症状对日常的影响。",
    time: "约 5–10 分钟",
    url: "https://wj.qq.com/s2/28334659/kkvo/"
  }
];

const list = document.getElementById("survey-list");
const toast = document.getElementById("toast");
let toastTimer = null;

window.POI_SURVEYS = surveys;

function showToast(message) {
  toast.textContent = message;
  toast.classList.remove("hidden");
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => toast.classList.add("hidden"), 2600);
}

if (list) {
  const categories = [...new Set(surveys.map(item => item.category))];

  categories.forEach(category => {
    const group = document.createElement("section");
    group.className = "survey-group";

    const heading = document.createElement("h2");
    heading.textContent = category;
    group.appendChild(heading);

    const grid = document.createElement("div");
    grid.className = "survey-grid";

    surveys.filter(item => item.category === category).forEach(item => {
      const card = document.createElement("article");
      card.className = "survey-card";

      const top = document.createElement("div");
      top.className = "survey-card-top";
      const tag = document.createElement("span");
      tag.className = "tag";
      tag.textContent = item.tag || "随访问卷";
      const time = document.createElement("span");
      time.className = "time";
      time.textContent = item.time;
      top.appendChild(tag);
      top.appendChild(time);

      const title = document.createElement("h3");
      title.textContent = item.name;
      const desc = document.createElement("p");
      desc.textContent = item.description;

      const button = document.createElement("button");
      button.className = "start-btn" + (item.url ? "" : " pending");
      button.textContent = item.url ? (item.actionLabel || "开始填写") : "链接待配置";
      button.addEventListener("click", () => {
        if (item.url) {
          window.open(item.url, "_blank", "noopener");
        } else {
          showToast("问卷链接待配置：请让研究团队填入腾讯文档链接。");
        }
      });

      card.appendChild(top);
      card.appendChild(title);
      card.appendChild(desc);
      card.appendChild(button);
      grid.appendChild(card);
    });

    group.appendChild(grid);
    list.appendChild(group);
  });
}
