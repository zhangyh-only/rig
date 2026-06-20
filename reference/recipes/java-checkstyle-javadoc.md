# recipe · Java「方法/声明必须有 Javadoc」接成靶向硬闸

把一条 **A 桶 presence 规则**（"方法/类/字段必须有 Javadoc" 这类存在性约束）从「只写在 `docs/conventions/code.md`」晋升为「真正拦得住的 checkstyle 检查」的现成范式。
这是 `/rig:learn` 三级进化里 **A 桶晋升**（规则进 `lint-one.sh` 配套的 linter 配置、被 `lint-changed` 自动拦）的一个实例，可直接抄。

## 为什么不能裸跑 `checkstyle:check`

`mvn checkstyle:check` 默认扫**全模块**——一接就把全仓历史欠账一次性全拦、且每次编辑都全量跑，与 lint-one「只检刚改的 `$f`」本意冲突。presence 类规则尤其致命：一接即炸，逼你停下手头活去补几百处存量注释。

## 接法：靠 lint-one 的 includes 做靶向 + 存量 grandfather

rig 的 `scripts/lint-one.sh` java 分支已经用 `-Dcheckstyle.includes=<改动文件相对 source root 的路径>` 把 checkstyle 限定到**刚改的那一个文件**。所以你只需把规则写进项目根 `checkstyle.xml`，它就天然「只打改动文件、存量 grandfather（改到那个文件才顺手收敛）」。

> 这比常见的三种纠结都好：不用 ①全仓先修齐（工作量大）、不用 ②人为划包先接（别的包新代码照漏）、也不用 ③`severity=warning` 先曝光（warning=没有真闸，新代码照样漏）。靶向 error 才是「真拦、但只拦你手上的文件」。

## 经实测的配置（方法必有 Javadoc）

```xml
<module name="Checker">
  <module name="TreeWalker">
    <!-- 声明级 Javadoc 禁单行块（配套，可选）：一行内同时出现 /** 与 */ 即报错，强制多行块。
         /** 两星号只命中 Javadoc，不误伤普通块注释 /* */。 -->
    <module name="RegexpSinglelineJava">
      <property name="format" value="/\*\*.*\*/"/>
      <property name="message" value="声明级 Javadoc 必须多行块，禁止单行 /** … */"/>
    </module>
    <module name="MissingJavadocMethod">
      <property name="scope" value="private"/>     <!-- 全可见性都查；只查 public/protected 改 protected -->
      <property name="tokens" value="METHOD_DEF"/>  <!-- 仅方法，不强制构造器（要管构造器加 CTOR_DEF） -->
      <property name="minLineCount" value="1"/>     <!-- 见下「易错点」 -->
    </module>
  </module>
  <!-- 测试方法用 should_xxx 描述命名、不强制 Javadoc：豁免 *Test/*Tests/*IT -->
  <module name="SuppressionSingleFilter">
    <property name="checks" value="MissingJavadocMethod"/>
    <property name="files" value=".*(Test|Tests|IT)\.java$"/>
  </module>
</module>
```

## 关键取舍（都实测过）

- **scope**：`private` = 全可见性（连 private helper 也要 Javadoc，对齐"方法都要多行块"的规范字面）；`protected` = 只 public/protected 契约面。按项目规范定。
- **@Override 自动豁免**：`MissingJavadocMethod` 的 `allowedAnnotations` 默认含 `Override`，继承方法不重复写文档，无需额外配置。
- **构造器**：`tokens` 只写 `METHOD_DEF` 即不强制构造器；要管构造器再加 `CTOR_DEF`。
- **`minLineCount`（易错点，务必实测）**：checkstyle 算的"方法行数" = 闭括号行号 − 左括号行号 − 1，**不含签名行与闭括号行**。sparring-upgrade 真机实测：
  | 值 | body 单行直返/getter | body 两行逻辑 | body 三行+ |
  |----|----|----|----|
  | 不设（默认 -1） | **拦** | 拦 | 拦 | ← 绝对全覆盖，连单行 getter 都要注释，易生低价值噪声 |
  | `1` | 放行 | **拦** | 拦 | ← **推荐**：豁免"一眼看懂"的单行直返，两行逻辑起强制 |
  | `2` | 放行 | 放行 | 拦 | ← 偏宽，连两行逻辑方法也放过 |
  推荐 `1`：既消灭"给 getter 凑废话注释、稀释 Javadoc 信号"，又不放过任何有逻辑的方法。
- **测试豁免**：`SuppressionSingleFilter` 按文件名正则豁免 `*Test/*Tests/*IT`。

## 实跑验证（rig 原则：不信纸面，造探针真跑）

在源码包下临时放探针（**跑完即删、绝不 git add**），用项目的 `lint-one.sh` 跑，三档都验过才算闸真的按预期咬合：

```bash
B=src/main/java/com/<pkg>            # 任一已有包
# ① 无 Javadoc 的两行方法 → 期望 exit≠0（拦）
# ② 给它补上 Javadoc      → 期望 exit 0（放行）
# ③ 无 Javadoc 的单行直返 → 期望 exit 0（被 minLineCount 豁免）
bash scripts/lint-one.sh "$B/__Probe.java"; echo "exit=$?"
rm -f "$B/__Probe.java"              # 立即清理
```

## 出处

2026-06 sparring-upgrade 真机沉淀：先接 presence 闸（commit `build(lint): 接 checkstyle MissingJavadocMethod`），再经 `minLineCount` 探针实测从 2 修正到 1。
