# Mindstorm · 邮箱账户阶段

此目录是发布包，可以放入 heyaqchen/Mindstorm 仓库根目录。它不包含浏览器中的私人文稿。

## 当前状态

已实现：人物账户入口、邮箱注册与登录、验证邮件重发、密码找回、账户名称与头像编辑、邮箱换绑、退出登录、按登录账户自动署名。
文稿目前仍保存在当前浏览器，并按账户区分；尚未实现文稿云端存储、Bunch 在线分享/成员权限和实时协作。不要把登录成功误认为文稿已经云端备份。

## 发布网页

1. 把本目录的文件上传至 GitHub 仓库根目录（包含 .github/workflows/pages.yml）。
2. 仓库 Settings → Pages → Source 选择 GitHub Actions。
3. 在 Actions 中运行 Publish Mindstorm，或向 main 分支提交以触发发布。
4. 预期网站地址：https://heyaqchen.github.io/Mindstorm/ 。这是配置的目标地址，不代表已成功上线。

也可以只上传 index.html、.nojekyll、SUPABASE-LICENSE.txt，在 Pages 中选择 Deploy from a branch → main → /(root)。私有仓库能否启用 Pages 取决于 GitHub 套餐；无需为此公开任何私人文稿。

## 配置现有 Supabase 项目

项目：https://supabase.com/dashboard/project/vwukwgqsohqzrelalmpk

1. SQL Editor 新建查询，执行 supabase/001-account.sql。它创建账户资料表及私有头像存储桶，并限制用户只读写自己的资料/头像。
2. Authentication → URL Configuration：
   - Site URL：https://heyaqchen.github.io/Mindstorm/
   - Redirect URLs：添加 https://heyaqchen.github.io/Mindstorm/
3. Authentication 中启用 Email 登录，保留邮箱验证。正式向普通用户发送注册/恢复邮件前，配置自定义 SMTP；Supabase 默认发信服务有收件人和频率限制。
4. 测试：注册 → 邮件验证 → 登录 → 修改昵称/头像 → 换绑邮箱验证 → 退出 → 再次登录。用第二个账户确认不能读取或覆盖第一个账户的头像。

网页只包含公开 Project URL 和 Publishable key；不要放入 service_role、secret key 或数据库密码。

## 验证范围与限制

已通过本地模拟接口测试（登录/注册确认/错误验证/资料修改/退出/账号切换）以及 JavaScript 语法检查。尚未在真实账户上发送验证邮件，也未执行服务器 SQL；当前环境访问 Supabase 出现网络中断，GitHub 仓库未取得登录权限。

本地 file:// 页面适合看界面，完整邮件回跳必须在发布后的 HTTPS 网站上测试。浏览器旧版文稿仍留在旧页面对应的浏览器存储中，不会随发布自动上传或迁移；先导出保存，再在新网站导入。

## 下一阶段

先做 Bunch 云端文档、分享邀请和 owner/editor/commenter/viewer 权限（数据库逐行权限校验），之后再做实时批注和有冲突处理的协同编辑。好友搜索和直接发给好友暂不实现。

参考：
- https://docs.github.com/en/pages/getting-started-with-github-pages/what-is-github-pages
- https://supabase.com/docs/guides/auth/redirect-urls
- https://supabase.com/docs/guides/auth/auth-smtp

第三方：Supabase JavaScript SDK 2.117.3，MIT 授权，见 SUPABASE-LICENSE.txt。
