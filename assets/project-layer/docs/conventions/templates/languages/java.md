# 语言模板：Java / Spring

适合：Java、Spring/Spring Boot、Maven/Gradle、多模块后端服务。

## 命名与分层
- [A桶] 类名、包名、测试类名跟随项目现有约定；新增包不得绕开既有分层。
- [B桶] Controller 只做协议转换和参数校验，不承载业务编排。
- [B桶] Service 承载业务流程；Repository/Mapper 只做数据访问。
- [B桶] DTO、VO、Entity、Param、Command 等模型含义必须和项目现有语义一致，不混用。

## 注释、日志与异常
- [B桶] 公共类、核心方法、复杂字段写 JavaDoc，解释用途、边界和约束。
- [B桶] 注释解释为什么和业务约束，不复述代码字面。
- [B桶] 日志包含关键业务标识和失败原因，不记录敏感数据。
- [B桶] 异常处理不静默吞掉；能恢复、需重试、需上抛要写清。

## 检查器建议
- [A桶] Checkstyle/Spotless：格式、import、注释存在性、命名。
- [A桶] ArchUnit：模块依赖、分层调用、禁止跨层访问。
- [A桶] Maven/Gradle test：单测、集成测试、架构测试。
- [A桶] `scripts/lint-one.sh` 对 Checkstyle 只检查当前改动文件，避免存量历史问题一次性拦住小改。

## 验证建议
- 小改：相关模块编译 + 聚焦单测。
- 多模块：受影响模块 `test` 或 `verify`。
- 依赖中间件：优先本地 profile、fake/stub、容器或可重复的 smoke，不把预发环境当唯一验证。
