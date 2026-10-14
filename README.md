# Mindstorm

Every idea counts.

网站：https://heyaqchen.github.io/Mindstorm/

## 已部署

- GitHub Pages：main 分支根目录，HTTPS。
- Supabase 项目：vwukwgqsohqzrelalmpk。
- 邮箱登录、注册、验证邮件重发、密码找回。
- 账户名字、头像、邮箱修改，以及自动作者署名。
- 账户资料表和私有头像存储；行级权限限制用户访问自己的资料。
- 认证 Site URL 与回跳白名单已设为上述网站地址。

## 当前范围

文稿仍保存在当前浏览器，并按账户区分；尚未实现云端文稿、Bunch 在线分享/成员权限和实时协作。登录不等于文稿已云端备份。

目前使用 Supabase 默认测试邮件服务；测试请使用该 Supabase 组织成员邮箱。正式开放其他人注册前需要配置自定义 SMTP。当前不启用付费发信，也不取消邮箱验证。

## 初始化与维护

001-account.sql 已在现有 Supabase 项目 SQL Editor 成功执行，创建账户资料及头像权限，保留副本供维护。它不删除文稿数据。

网页内仅包含公开项目 URL 与 Publishable key，不得加入 service_role、secret key 或数据库密码。

本地旧文稿不会随网站发布自动上传，请先在原本地页面导出，然后在新网站导入。

## 检查记录

本地模拟登录/注册确认/密码不一致/资料修改/退出/账户隔离测试通过，发布文件脚本语法检查通过。线上首页与登录入口正常，未发现浏览器错误。完整邮件验证和真实用户登录由项目所有者测试。

## 后续顺序

Bunch 云端保存、分享链接与成员权限 → 实时批注 → 有冲突处理的协同编辑。暂不制作好友搜索或直接发送给好友。

Supabase JavaScript SDK 2.117.3 的 MIT 授权见 SUPABASE-LICENSE.txt；该授权文件仅适用于第三方 SDK，不是 Mindstorm 自身的授权声明。
