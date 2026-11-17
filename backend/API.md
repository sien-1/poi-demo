# POI 后端 MVP 接口

基础地址：`http://127.0.0.1:8765`

除 `/health` 外，所有请求都需要演示身份头：

```http
X-Demo-Token: doctor-c001
```

所有响应使用 JSON。错误统一返回：

```json
{
  "error": {
    "code": "FORBIDDEN",
    "message": "当前角色不能执行该操作。"
  }
}
```

## 通用列表参数

患者列表和任务列表支持：

| 参数 | 说明 |
|---|---|
| `page` | 页码，从 1 开始 |
| `pageSize` | 每页数量，最大 100 |
| `q` | 患者编号、研究编号或任务名称检索 |
| `status` | 状态过滤 |

任务列表还支持：

| 参数 | 说明 |
|---|---|
| `patientId` | 在权限范围内按患者过滤 |
| `visitNo` | 按随访序号过滤 |
| `from` | 截止日期下限，格式 `YYYY-MM-DD` |
| `to` | 截止日期上限，格式 `YYYY-MM-DD` |

列表返回：

```json
{
  "items": [],
  "meta": {
    "page": 1,
    "pageSize": 20,
    "total": 0,
    "totalPages": 0
  }
}
```

## 接口清单

### `GET /health`

无需身份。返回服务状态和存储模式。`storage` 固定为 `synthetic-in-memory`。

### `GET /api/v1/metadata`

返回数据分类、角色、资源类别、API 版本和正式存储要求。

### `GET /api/v1/me`

返回服务端解析出的当前身份和允许的数据范围。客户端提交的医院、科室、角色或患者编号不能覆盖该结果。

### `GET /api/v1/patients`

按当前身份返回患者摘要。患者本人不能访问患者目录。医生摘要只包含：

```json
{
  "patientId": "PAT-001",
  "studyCode": "POI-DEMO-001",
  "ageBand": "30-34",
  "status": "follow_up",
  "currentDepartment": "妇科内分泌科（演示）",
  "nextVisitAt": "2026-12-01"
}
```

不返回姓名、电话、证件号或原始出生日期。研究人员只返回 `studyCode`、年龄段、研究状态和同意状态。

### `GET /api/v1/patients/{patientId}`

返回权限范围内患者、诊疗关系、访视、近期任务和问卷摘要。医生看不到其他单位的历史关系；医院管理员可以查看本院内的转科历史。

### `GET /api/v1/patients/{patientId}/visits`

按单位范围返回患者访视，支持分页。转科前的访视保留原科室和原医生。

### `GET /api/v1/patients/{patientId}/tasks`

按单位范围返回患者任务，支持任务列表的全部过滤参数。

### `GET /api/v1/tasks`

按身份返回任务列表。患者只能看到本人任务；医生只看到由自己在该有效单位中下发的任务；科室和医院管理员按单位范围查看。

### `POST /api/v1/tasks/{taskId}/complete`

仅患者本人可调用。请求体可为空。首次完成返回 `alreadyCompleted: false`，已完成后再次调用返回 `alreadyCompleted: true`，不会产生第二条完成记录。

### `GET /api/v1/questionnaires/{bundleId}`

患者返回中性标题“健康随访问卷”和题项，不返回量表内部计分名称。医生和管理员返回问卷状态、量表版本和提交摘要，不返回原始答案。

### `POST /api/v1/questionnaires/{bundleId}/submit`

仅患者本人可调用。请求示例：

```json
{
  "answers": [
    { "questionId": "KUP-01", "value": "1" },
    { "questionId": "KUP-02", "value": "2" }
  ]
}
```

必填题项缺失或出现未知题项时返回 `400`。首次提交返回 `201`；同一问卷再次提交返回 `409 ALREADY_SUBMITTED`。

### `GET /api/v1/visits/{visitId}`

返回当前账号有权访问的访视。无权和不存在的响应一致，均返回 `404`。

### `POST /api/v1/batches/task-generation`

仅医生可调用。请求示例：

```json
{
  "visitIds": ["VIS-002-02"],
  "templateId": "TPL-POI-3M",
  "idempotencyKey": "demo-batch-001"
}
```

返回 `success`、`skipped` 和 `failed` 三部分：

```json
{
  "batchId": "BATCH-...",
  "idempotentReplay": false,
  "success": [],
  "skipped": [],
  "failed": []
}
```

规则：

- 同一医生使用同一 `idempotencyKey` 重试时返回原批次结果。
- 重复访视编号跳过。
- 无权或不存在的访视不暴露区别。
- 一个批次不能跨医院、科室或医生。
- 任务中的单位字段固定为生成时上下文。

### `GET /api/v1/audit`

仅科室管理员和医院管理员可调用。科室管理员只看到本科室事件，医院管理员只看到本院事件。审计记录包括操作者、动作、对象类型、对象编号、结果、单位、时间和来源。

## 状态码

| 状态码 | 含义 |
|---|---|
| `200` | 查询成功或安全幂等重放 |
| `201` | 问卷首次提交成功 |
| `400` | JSON、参数或答案结构无效 |
| `401` | 缺少或无效的演示身份 |
| `403` | 角色明确不允许该操作 |
| `404` | 对象不存在或当前账号无权确认其存在 |
| `409` | 对象状态冲突或重复写入 |
| `500` | 未处理的内部错误 |
