const formRoot = document.getElementById("survey-form");
const progressText = document.getElementById("progress-text");
const progressBar = document.getElementById("progress-bar");
const fullToast = document.getElementById("toast");
let fullToastTimer = null;

function showFullToast(message) {
  fullToast.textContent = message;
  fullToast.classList.remove("hidden");
  clearTimeout(fullToastTimer);
  fullToastTimer = setTimeout(() => fullToast.classList.add("hidden"), 2800);
}

function option(name, text, type = "radio") {
  return `
    <label class="option">
      <input type="${type}" name="${name}" value="${text}" />
      <span>${text}</span>
    </label>
  `;
}

function options(name, items, type = "radio") {
  return `<div class="option-grid">${items.map(text => option(name, text, type)).join("")}</div>`;
}

function question(key, number, title, body, note = "") {
  return `
    <fieldset class="question" data-question="${key}">
      <legend>${number}. ${title}</legend>
      ${note ? `<p class="question-note">${note}</p>` : ""}
      ${body}
    </fieldset>
  `;
}

function section(id, number, title, subtitle, body, collapsed = false) {
  return `
    <section class="form-section${collapsed ? " is-collapsed" : ""}" id="${id}">
      <button class="section-toggle" type="button" aria-expanded="${collapsed ? "false" : "true"}">
        <span class="section-number">${number}</span>
        <span class="section-heading">
          <strong>${title}</strong>
          <small>${subtitle}</small>
        </span>
        <span class="section-chevron">⌄</span>
      </button>
      <div class="section-body">${body}</div>
    </section>
  `;
}

function findScaleLink(keyword) {
  const items = Array.isArray(window.POI_SURVEYS) ? window.POI_SURVEYS : [];
  const match = items.find(item => item.name.includes(keyword) && item.category !== "研究完整版");
  return match ? match.url : "survey.html";
}

function scaleCard(key, name, description) {
  const url = findScaleLink(key);
  return `
    <a class="scale-link" href="${url}" target="_blank" rel="noopener">
      <strong>${name}</strong>
      <span>${description}</span>
      <b>打开量表 →</b>
    </a>
  `;
}

const labRows = [
  "AMH（ng/mL）",
  "FSH（U/L）",
  "LH（U/L）",
  "E2（pg/mL）",
  "双侧卵巢体积（cm³）",
  "AFC（个，左 + 右）",
  "子宫内膜厚度（mm）",
  "其他超声所见"
];

const sections = [
  section(
    "basic",
    "01",
    "基本信息与辅助检查",
    "基础资料、月经初潮及近期相关检查",
    `
      ${question(
        "age",
        "1",
        "年龄（周岁）",
        `
          <div class="field-row">
            <input class="number-input" type="number" min="18" max="60" inputmode="numeric" aria-label="年龄" />
            <span class="inline-label">岁</span>
          </div>
          ${options("age-range", ["18–25", "26–30", "31–35", "36–40"])}
        `
      )}
      ${question(
        "body",
        "2",
        "身高与体重",
        `
          <div class="field-row">
            <label for="height">身高</label>
            <input id="height" class="number-input" type="number" min="100" max="220" inputmode="decimal" />
            <span class="inline-label">cm</span>
            <label for="weight">体重</label>
            <input id="weight" class="number-input" type="number" min="20" max="200" inputmode="decimal" />
            <span class="inline-label">kg</span>
            <span id="bmi-result" class="bmi-pill">BMI 自动计算</span>
          </div>
        `
      )}
      ${question("residence", "3", "长期居住地", options("residence", ["城市", "乡镇", "农村"]))}
      ${question(
        "education",
        "4",
        "文化程度",
        options("education", ["初中及以下", "高中/中专", "本科/大专", "研究生及以上"])
      )}
      ${question(
        "menarche",
        "5",
        "月经初潮年龄",
        `
          <div class="field-row">
            <input class="number-input" type="number" min="8" max="25" inputmode="numeric" aria-label="月经初潮年龄" />
            <span class="inline-label">岁</span>
          </div>
        `
      )}
      ${question(
        "labs",
        "辅助检查",
        "AMH 与超声结果记录",
        `
          <p class="question-note">已有 AMH 或 AFC 结果者，建议携带报告一并就诊，便于与本次评分对照。演示页不保存这些信息。</p>
          <div class="lab-list">
            ${labRows
              .map(
                name => `
                  <div class="lab-row">
                    <span class="lab-name">${name}</span>
                    <input class="text-input" type="text" placeholder="结果 / 描述" aria-label="${name}结果" />
                    <input class="date-input" type="date" aria-label="${name}检查时间" />
                    <input class="text-input" type="text" placeholder="机构 / 备注" aria-label="${name}机构或备注" />
                  </div>
                `
              )
              .join("")}
          </div>
        `
      )}
    `
  ),
  section(
    "history",
    "02",
    "遗传与既往疾病",
    "家族史、疾病史与医源性因素",
    `
      ${question(
        "family-poi",
        "6",
        "母亲或姐妹是否有 40 岁前绝经或被判为“卵巢早衰/POI”？",
        `
          ${options("family-poi", ["否", "不清楚", "是"])}
          <div class="field-row">
            <label>如是，关系：</label>
            <input class="text-input" type="text" placeholder="如母亲、姐妹" />
          </div>
        `
      )}
      ${question(
        "family-autoimmune",
        "7",
        "家族中是否有自身免疫性疾病（桥本甲状腺炎、系统性红斑狼疮、类风湿关节炎、Addison 病等）？",
        `
          ${options("family-autoimmune", ["否", "是"])}
          <div class="field-row">
            <label>如是，请说明：</label>
            <input class="text-input" type="text" />
          </div>
        `
      )}
      ${question(
        "disease-history",
        "8",
        "是否曾因以下疾病接受治疗？",
        options(
          "disease-history",
          [
            "恶性肿瘤（尤其盆腔/淋巴系统）",
            "血液系统疾病（需化疗/骨髓移植）",
            "系统性红斑狼疮、类风湿关节炎等自身免疫病",
            "甲状腺疾病（甲亢/甲减/甲状腺炎）",
            "无上述疾病"
          ],
          "checkbox"
        )
      )}
      ${question(
        "infection-history",
        "9",
        "是否曾患腮腺炎、风疹、结核、水痘等感染？",
        `
          ${options("infection-history", ["否", "是"])}
          <div class="field-row">
            <label>如是，请说明：</label>
            <input class="text-input" type="text" />
          </div>
        `
      )}
      ${question(
        "pelvic-treatment",
        "10",
        "是否接受过盆腔放射或化疗？",
        `
          ${options("pelvic-treatment", ["否", "是"])}
          <div class="field-row">
            <label>如是，部位 / 药物：</label>
            <input class="text-input" type="text" />
          </div>
        `
      )}
      ${question(
        "surgery-history",
        "11",
        "是否有卵巢或子宫手术史？",
        options(
          "surgery-history",
          [
            "卵巢囊肿剔除术",
            "卵巢巧克力囊肿（子宫内膜异位囊肿）手术",
            "单侧/双侧卵巢切除",
            "子宫肌瘤剔除术",
            "剖宫产",
            "无手术史"
          ],
          "checkbox"
        )
      )}
      ${question(
        "pregnancy-history",
        "12",
        "是否有不良妊娠史，如自然流产、生化妊娠、胚胎停育？",
        `
          ${options("pregnancy-history", ["否", "是"])}
          <div class="field-row">
            <label>如是，请说明：</label>
            <input class="text-input" type="text" />
          </div>
        `
      )}
      ${question(
        "uterine-procedure",
        "13",
        "是否有人工流产或宫腔手术史？",
        `
          ${options("uterine-procedure", ["否", "是"])}
          <div class="field-row">
            <label>如是，次数：</label>
            <input class="number-input" type="number" min="1" inputmode="numeric" />
            <span class="inline-label">次</span>
          </div>
        `
      )}
      ${question(
        "ovarian-drugs",
        "14",
        "是否长期服用可能影响卵巢功能的药物（如雷公藤制剂、化疗药、长期大剂量孕激素等）？",
        `
          ${options("ovarian-drugs", ["否", "是"])}
          <div class="field-row">
            <label>如是，请说明：</label>
            <input class="text-input" type="text" />
          </div>
        `
      )}
    `
  ),
  section(
    "lifestyle",
    "03",
    "生活方式与环境暴露",
    "吸烟、饮酒、睡眠、运动及职业暴露",
    `
      ${question(
        "smoking",
        "15",
        "是否吸烟？",
        `
          ${options("smoking", ["否", "是"])}
          <div class="field-row">
            <label>开始年龄</label>
            <input class="number-input" type="number" min="0" inputmode="numeric" />
            <span class="inline-label">岁</span>
            <label>频率</label>
            <input class="number-input" type="number" min="0" inputmode="numeric" />
            <span class="inline-label">支/日</span>
          </div>
        `
      )}
      ${question(
        "secondhand-smoke",
        "16",
        "是否经常处于二手烟环境？",
        `
          ${options("secondhand-smoke", ["否", "是"])}
          <div class="field-row">
            <label>如是，约</label>
            <input class="number-input" type="number" min="0" inputmode="decimal" />
            <span class="inline-label">小时/日</span>
          </div>
        `
      )}
      ${question("alcohol", "17", "饮酒频率？", options("alcohol", ["不喝", "偶尔", "时常", "每天"]))}
      ${question("drug-use", "18", "是否有吸毒史？", options("drug-use", ["否", "是"]))}
      ${question(
        "late-night",
        "19",
        "是否经常熬夜（23:00 后入睡，每周 ≥ 3 次）？",
        options("late-night", ["几乎不", "偶尔", "经常", "几乎每天"])
      )}
      ${question(
        "exercise",
        "20",
        "运动情况？",
        options("exercise", ["每天", "每周 3–5 次", "每周 1–2 次", "偶尔", "基本不运动"])
      )}
      ${question(
        "dieting",
        "21",
        "是否节食、刻意减重或 BMI < 18.5？",
        `
          ${options("dieting", ["否", "是"])}
          <div class="field-row">
            <label>如是，最低体重</label>
            <input class="number-input" type="number" min="0" inputmode="decimal" />
            <span class="inline-label">kg</span>
          </div>
        `
      )}
      ${question(
        "exposure",
        "22",
        "职业/生活中是否接触放射线或化学毒物（农药、染发剂、装修材料、工业化学品）？",
        options("exposure", ["无", "放射线", "化学毒物", "两者均有"], "checkbox")
      )}
    `
  ),
  section(
    "menstrual",
    "04",
    "月经、痛经与相关表现",
    "月经模式、生育相关情况及雌激素缺乏表现",
    `
      ${question(
        "cycle-length",
        "23",
        "月经周期长度（两次月经第 1 天的间隔）",
        `
          ${options("cycle-length", ["规律（21–35 天，周期变异 ≤ 7 天）", "频发（< 21 天）", "稀发（36–90 天）", "闭经（> 90 天）"])}
          <div class="field-row">
            <label>闭经约</label>
            <input class="number-input" type="number" min="0" inputmode="numeric" />
            <span class="inline-label">个月</span>
          </div>
        `
      )}
      ${question(
        "period-duration",
        "24",
        "经期持续天数",
        options("period-duration", ["≤ 3 天", "4–7 天（正常）", "8–10 天", "> 10 天（淋漓不尽）"])
      )}
      ${question(
        "regularity",
        "25",
        "近 1 年月经规律性",
        options("regularity", ["规律（周期变异 ≤ 7 天）", "不规律（周期变异 > 7 天）"])
      )}
      ${question(
        "cycle-changes",
        "26",
        "近 3 个月月经改变（可多选）",
        options(
          "cycle-changes",
          [
            "周期延长或稀发（≥ 35 天）",
            "停经或闭经（≥ 6 个月）",
            "月经量明显减少",
            "经期延长或淋漓不尽",
            "无上述改变"
          ],
          "checkbox"
        )
      )}
      ${question(
        "flow",
        "27",
        "月经量（按卫生巾使用量估计）",
        options("flow", [
          "正常",
          "偏少",
          "极少（点滴状，每日 1–2 片护垫）",
          "月经过多（1–2 小时浸透 1 片卫生巾或需夜间更换）"
        ])
      )}
      ${question(
        "fertility-unmet",
        "28",
        "是否有生育要求但未避孕 1 年未孕？",
        `
          ${options("fertility-unmet", ["无生育要求", "有，备孕不足 6 个月", "有，备孕 6–12 个月", "有，备孕超过 12 个月"])}
        `
      )}
      ${question(
        "estrogen-symptoms",
        "29",
        "是否出现以下雌激素缺乏表现？（可多选）",
        options(
          "estrogen-symptoms",
          [
            "潮热、烘热、夜间出汗",
            "阴道干涩、性交疼痛",
            "性欲减退",
            "失眠、心悸",
            "情绪易激动、焦虑、抑郁",
            "骨痛、关节痛、身高变矮",
            "记忆力下降、疲乏无力"
          ],
          "checkbox"
        )
      )}
      ${question(
        "dysmenorrhea",
        "30",
        "痛经程度（近 1 年平均发作时）",
        options("dysmenorrhea", [
          "无痛经",
          "轻度（不影响学习/工作，无需服药）",
          "中度（影响注意力，需服止痛药缓解）",
          "重度（需卧床、影响日常活动，止痛药效果差）"
        ])
      )}
    `
  ),
  section(
    "quality",
    "05",
    "症状与生活质量专项量表",
    "31–32：由研究方案选择对应量表",
    `
      ${question(
        "menqol",
        "31",
        "围绝经期生存质量量表（MENQOL）",
        `<div class="scale-grid">${scaleCard("MENQOL", "MENQOL", "评估近期生活质量及症状对日常的影响。")}</div>`
      )}
      ${question(
        "cmss",
        "32",
        "COX 痛经症状量表（CMSS）",
        `<div class="scale-grid">${scaleCard("CMSS", "CMSS", "记录痛经相关症状及严重程度。")}</div>`
      )}
    `
  ),
  section(
    "mental",
    "06",
    "心理、情绪与睡眠",
    "33–38：按研究流程和施测要求使用",
    `
      ${question(
        "hamd",
        "33",
        "汉密尔顿抑郁量表（HAMD）",
        `<div class="scale-grid">${scaleCard("HAMD", "HAMD", "抑郁相关症状评估，需由研究团队确认施测方式。")}</div>`
      )}
      ${question(
        "hama",
        "34",
        "汉密尔顿焦虑量表（HAMA）",
        `<div class="scale-grid">${scaleCard("HAMA", "HAMA", "焦虑相关症状评估，结果需结合临床判断。")}</div>`
      )}
      ${question(
        "cpss",
        "35",
        "压力知觉量表（CPSS）",
        `<div class="scale-grid">${scaleCard("CPSS", "CPSS", "评估近期主观压力水平。")}</div>`
      )}
      ${question(
        "bsi",
        "36",
        "贝克自杀意念量表中文版（BSI-CV）",
        `<div class="scale-grid">${scaleCard("BSI-CV", "BSI-CV", "涉及敏感心理条目；如出现明显不适，请暂停并联系研究团队。")}</div>`
      )}
      ${question(
        "ais",
        "37",
        "阿森斯失眠量表（AIS）",
        `<div class="scale-grid">${scaleCard("AIS", "AIS", "睡眠困难及日间影响的自评。")}</div>`
      )}
      ${question(
        "psqi",
        "38",
        "匹兹堡睡眠质量指数（PSQI）",
        `<div class="scale-grid">${scaleCard("PSQI", "PSQI", "评估近一个月的睡眠质量与睡眠相关问题。")}</div>`
      )}
    `,
    true
  ),
  section(
    "bone",
    "07",
    "Kupperman、骨质疏松与认知",
    "39–43：按研究方案选用，不需要全部填写",
    `
      <div class="scale-grid" style="margin: 16px 0 4px;">
        ${scaleCard("Kupperman", "Kupperman 量表", "围绝经期症状评估；11 项与 13 项版本按方案二选一。")}
      </div>
      ${question(
        "iof",
        "39",
        "IOF 一分钟骨质疏松风险测试",
        `<div class="scale-grid">${scaleCard("IOF 一分钟", "IOF 一分钟", "骨质疏松风险快速筛查。")}</div>`
      )}
      ${question(
        "osta",
        "40",
        "亚洲骨质疏松自我评估工具（OSTA）",
        `<div class="scale-grid">${scaleCard("OSTA", "OSTA", "骨质疏松自我筛查工具。")}</div>`
      )}
      ${question(
        "frax",
        "41",
        "FRAX（WHO 骨折风险评估工具）",
        `<div class="scale-grid">${scaleCard("FRAX", "FRAX", "骨折风险评估工具，需按研究要求录入相应参数。")}</div>`
      )}
      ${question(
        "mmse",
        "42",
        "简易精神状态检查（MMSE）",
        `<div class="scale-grid">${scaleCard("MMSE", "MMSE", "认知功能筛查，具体施测方式按研究流程执行。")}</div>`
      )}
      ${question(
        "moca",
        "43",
        "蒙特利尔认知评估（MoCA）",
        `<div class="scale-grid">${scaleCard("MoCA", "MoCA", "认知评估，具体施测方式按研究流程执行。")}</div>`
      )}
    `,
    true
  ),
  section(
    "fertility",
    "08",
    "生育意愿",
    "最后一组问题",
    `
      ${question(
        "fertility-intention",
        "44",
        "是否有生育意愿？",
        `
          ${options("fertility-intention", ["无", "有"])}
          <div class="field-row">
            <label>如有，具体的生育规划是：</label>
            <input class="text-input" type="text" placeholder="可填写期望时间或计划" />
          </div>
        `
      )}
    `
  )
];

formRoot.innerHTML = sections.join("");

formRoot.addEventListener("click", event => {
  const toggle = event.target.closest(".section-toggle");
  if (!toggle) return;
  const sectionElement = toggle.closest(".form-section");
  const collapsed = sectionElement.classList.toggle("is-collapsed");
  toggle.setAttribute("aria-expanded", String(!collapsed));
});

function updateBmi() {
  const height = Number(document.getElementById("height").value);
  const weight = Number(document.getElementById("weight").value);
  const result = document.getElementById("bmi-result");
  if (!height || !weight) {
    result.textContent = "BMI 自动计算";
    return;
  }
  const bmi = weight / ((height / 100) ** 2);
  result.textContent = `BMI ${bmi.toFixed(1)}`;
}

function isQuestionAnswered(questionElement) {
  const checked = questionElement.querySelector("input[type='radio']:checked, input[type='checkbox']:checked");
  if (checked) return true;
  return [...questionElement.querySelectorAll("input[type='text'], input[type='number'], input[type='date'], textarea")].some(
    input => input.value.trim() !== ""
  );
}

function trackedQuestions() {
  return [...formRoot.querySelectorAll(".question")].filter(
    questionElement => !questionElement.querySelector(".scale-link")
  );
}

function updateProgress() {
  const questions = trackedQuestions();
  const answered = questions.filter(isQuestionAnswered).length;
  progressText.textContent = `已填写 ${answered} / ${questions.length}`;
  progressBar.style.width = questions.length ? `${(answered / questions.length) * 100}%` : "0%";
}

document.getElementById("height").addEventListener("input", updateBmi);
document.getElementById("weight").addEventListener("input", updateBmi);
formRoot.addEventListener("input", updateProgress);
formRoot.addEventListener("change", updateProgress);
updateProgress();

document.getElementById("complete-preview").addEventListener("click", () => {
  const questions = trackedQuestions();
  const firstUnanswered = questions.find(item => !isQuestionAnswered(item));
  if (firstUnanswered) {
    firstUnanswered.closest(".form-section")?.classList.remove("is-collapsed");
    firstUnanswered.scrollIntoView({ behavior: "smooth", block: "center" });
    firstUnanswered.classList.remove("is-highlighted");
    window.requestAnimationFrame(() => firstUnanswered.classList.add("is-highlighted"));
    showFullToast("还有未填写的题目，已定位到该部分。本页仅作演示，不会上传答案。");
    return;
  }
  showFullToast("完整版填写预览已完成。本演示页不会保存或上传答案。");
});
