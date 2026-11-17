# GitHub仓库保护清单

以下项目需要仓库管理员权限，部分操作不能仅通过本地 Git 完成。

## 已准备的仓库文件

- `.github/CODEOWNERS`
- `.github/pull_request_template.md`
- `.github/workflows/validate.yml`

## 需要在 GitHub 网页启用的设置

1. 为账号开启两步验证。
2. 确认仓库可见性和团队成员权限。
3. 保护 `main` 分支：
   - 禁止直接强制推送。
   - 禁止删除分支。
   - 要求 Pull Request 后合并。
   - 要求验证工作流通过。
   - 要求 CODEOWNERS 审核。
4. 为每位成员使用独立仓库账号，不共享凭据。
5. 定期检查 Deploy keys、Personal access tokens 和第三方应用权限。
6. 若仓库公开，检查是否包含团队内部文档、未公开量表或研究方案。

## 签名提交

如需让 GitHub 显示 `Verified`：

1. 生成个人 SSH 或 GPG 签名密钥。
2. 将公钥添加到 GitHub 的签名密钥设置。
3. 在本地仓库设置 `gpg.format`、`user.signingkey` 和 `commit.gpgsign`。
4. 创建一次签名提交，并确认 GitHub 显示 `Verified`。

签名密钥的创建与上传属于账号安全操作，应在本人确认密钥保存和备份方式后执行。
