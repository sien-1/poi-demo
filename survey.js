// 把腾讯文档问卷链接填到每项的 url 字段即可。
// 例如：url: "https://docs.qq.com/form/page/xxxxxxxx"

const surveys = [
  {
    category: "心理与情绪",
    name: "汉密尔顿抑郁量表（HAMD）",
    description: "抑郁相关症状评估，需按研究团队指定的时间点填写。",
    time: "约 10–15 分钟",
    url: ""
  },
  {
    category: "心理与情绪",
    name: "汉密尔顿焦虑量表（HAMA）",
    description: "焦虑相关症状评估，结果需结合临床判断。",
    time: "约 10–15 分钟",
    url: ""
  },
  {
    category: "心理与情绪",
    name: "贝克自杀意念量表（BSI-CV）",
    description: "涉及敏感心理条目；如出现明显不适，请暂停并联系研究团队。",
    time: "约 5–10 分钟",
    url: ""
  },
  {
    category: "睡眠与压力",
    name: "匹兹堡睡眠质量指数（PSQI）",
    description: "评估近一个月的睡眠质量与睡眠相关问题。",
    time: "约 5–10 分钟",
    url: ""
  },
  {
    category: "睡眠与压力",
    name: "阿森斯失眠量表（AIS）",
    description: "睡眠困难及相关日间影响的自评。",
    time: "约 3–5 分钟",
    url: ""
  },
  {
    category: "睡眠与压力",
    name: "压力知觉量表（CPSS）",
    description: "评估近期主观感受到的压力水平。",
    time: "约 3–5 分钟",
    url: ""
  },
  {
    category: "症状与生活质量",
    name: "Kupperman 量表（原版 / NMPA 改良版）",
    description: "围绝经期相关症状评估，按研究团队指定版本填写。",
    time: "约 3–5 分钟",
    url: ""
  },
  {
    category: "症状与生活质量",
    name: "围绝经期生存质量量表（MENQOL）",
    description: "评估近期生活质量及症状对日常的影响。",
    time: "约 5–10 分钟",
    url: ""
  },
  {
    category: "症状与生活质量",
    name: "痛经症状量表（CMSS）",
    description: "记录痛经相关症状及严重程度。",
    time: "约 3–5 分钟",
    url: ""
  },
  {
    category: "认知与骨骼健康",
    name: "认知功能（MMSE、MoCA）",
    description: "认知功能筛查量表；具体版本与施测方式由研究团队确认。",
    time: "约 10–15 分钟",
    url: ""
  },
  {
    category: "认知与骨骼健康",
    name: "骨质疏松（IOF、OSTA、FRAX）",
    description: "骨骼健康风险相关评估工具，按研究流程选择。",
    time: "约 5–10 分钟",
    url: ""
  }
];

const list = document.getElementById("survey-list");
const toast = document.getElementById("toast");
let toastTimer = null;

function showToast(message) {
  toast.textContent = message;
  toast.classList.remove("hidden");
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => toast.classList.add("hidden"), 2600);
}

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
    tag.textContent = "随访问卷";
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
    button.textContent = item.url ? "开始填写" : "链接待配置";
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
