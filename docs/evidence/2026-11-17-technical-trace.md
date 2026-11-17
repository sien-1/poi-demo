# 2026-11-17 技术留痕设置

## 本次完成

- 建立项目 README 和工作日志。
- 建立 4 项关键架构决策记录。
- 建立日期化交付证据目录。
- 建立静态验证脚本和 GitHub Actions 验证工作流。
- 建立技术维护范围 `CODEOWNERS`。
- 建立 Pull Request 证据模板。
- 生成项目专用 SSH 提交签名密钥。
- 启用本仓库的提交和标签签名。

## 提交签名

- 签名格式：SSH Ed25519
- 公钥指纹：
  `SHA256:9kaphVpcN8H5BvYkBAhdJdznCgiBi3z65wtBDiwXbHo`
- 公钥文件：`docs/evidence/poi-demo-signing-ed25519.pub`
- 允许签名者文件：`docs/evidence/allowed_signers`
- 私钥位置：仓库外，由技术维护者本地保存
- Git 配置：
  - `gpg.format=ssh`
  - `commit.gpgsign=true`
  - `tag.gpgsign=true`
  - `gpg.ssh.allowedSignersFile=<仓库内 allowed_signers>`

本地可以使用以下命令检查：

```powershell
git log --show-signature -1
```

## 静态验证

执行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\validate-project.ps1
```

运行结果：

```text
PASS    local HTML links resolve
PASS    HTML ids are unique per page
PASS    CMSS is absent from survey configuration
PASS    Kupperman 11-item version is absent
PASS    Kupperman 13-item version is retained
PASS    MMSE and MoCA are excluded from patient questionnaire configuration
PASS    MMSE and MoCA are present in the doctor workspace
PASS    questionnaire numbers are continuous from 1 to 41
SUMMARY checks=8 passed, 0 failed
```

## 仍需账号管理员完成的设置

- 将公钥添加到 GitHub 账号的 SSH signing keys。
- 保护 `main` 分支，禁止强制推送和删除。
- 要求 Pull Request 和验证工作流通过后合并。
- 确认仓库成员仅拥有必要权限。

具体步骤见 `docs/github-protection-checklist.md`。

## 边界说明

技术签名和提交记录用于证明技术过程与版本来源，不单独决定论文、专利、软著或其他团队成果的最终署名和权利归属。
