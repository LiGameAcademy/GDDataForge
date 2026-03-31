# GDDataForge 统一数据管线架构设计（实现前文档）

## 1. 背景与问题

当前项目存在两个高风险趋势：

- 编辑器侧（可视化数据编辑器）有一套数据读写与校验逻辑。
- 运行时侧（DataManager / 动态 Resource）有另一套数据加载与缓存逻辑。

这会导致：

- 解析规则分叉（CSV/JSON/custom loader 行为不一致）。
- 保存后表现与运行时读取结果不一致。
- 新增格式时要改两套代码，维护成本高。

## 2. 目标

建立**单一数据管线**，编辑器与运行时共享同一套核心数据逻辑。

核心能力：

- 支持 `csv/json/自定义加载器`。
- 统一解析为中间模型（标准化文档结构）。
- 统一缓存为字典结构。
- 可动态投影为 `Resource`。
- 编辑器只做 UI/交互，不承载格式实现细节。

## 3. 总体架构

建议拆为 4 层（`addons/GDDataForge/core/`）：

1. `adapter`（格式适配层）
2. `document`（中间模型层）
3. `repository`（缓存/读写协调层）
4. `resource_builder`（运行时资源构建层）

### 3.1 数据流

`文件(任意格式)` -> `Adapter` -> `TableDocument` -> `Repository Cache(Dictionary)` -> `ResourceBuilder` -> `Resource实例`

反向保存：

`编辑器修改 TableDocument` -> `Repository.save()` -> `Adapter.write()`

## 4. 核心数据结构

### 4.1 TableDocument（统一中间模型）

建议字段：

- `table_id: String`
- `source_path: String`
- `source_format: String` (`csv/json/custom`)
- `meta: Dictionary`
  - `columns: Array[String]`
  - `types: Array[String]`
  - `primary_key: String`
  - `validation_rules: Dictionary`
  - `foreign_keys: Array[Dictionary]`
- `rows: Dictionary` (`{row_id: {field:value}}`)
- `row_order: Array[String]`

### 4.2 RuntimeCacheEntry

- `document: TableDocument`
- `version: int`（可选）
- `dirty: bool`
- `last_loaded_ms: int`

## 5. 适配器接口（扩展点）

定义 `IDataAdapter`（约定接口）：

- `can_handle(path: String) -> bool`
- `load(path: String) -> TableDocument`
- `save(path: String, doc: TableDocument) -> bool`
- `format_name() -> String`

默认实现：

- `CsvAdapter`
- `JsonAdapter`

扩展实现：

- `CustomAdapter`（由游戏项目注入）

## 6. Repository 责任边界

`DataRepository` 负责：

- Adapter 选择与调度
- 统一 load/save
- 缓存生命周期管理
- reload/invalidate/hot-reload
- 对外提供统一查询接口

编辑器和运行时都调用 `DataRepository`，不再各自直连文件解析。

## 7. 编辑器与运行时如何接入

### 7.1 编辑器接入原则

- UI 层仅操作 `TableDocument`。
- `打开/保存/批量打开` 全部走 `DataRepository`。
- 编辑器中的 `table_data_io.gd` 逐步退化为兼容桥接层，最终移除。

### 7.2 运行时接入原则

- DataManager 从 `DataRepository` 获取 `TableDocument`。
- 需要模型化时，通过 `ResourceBuilder` 投影生成 `Resource`。
- 运行时缓存与编辑器缓存使用同一份规范（可共享序列化协议）。

## 8. 迁移策略（低风险）

### Phase A（骨架）

- 新建 `core/` 目录与接口。
- 实现 `TableDocument`、`CsvAdapter`、`JsonAdapter`、`DataRepository`。
- 不改 UI，先在编辑器中做并行试运行。

### Phase B（编辑器切换）

- 可视化编辑器读写全面改为 `DataRepository`。
- 保留旧逻辑开关（fallback）一段时间。

### Phase C（运行时切换）

- DataManager 切换到 `DataRepository + ResourceBuilder`。
- 删除重复的运行时解析逻辑。

### Phase D（扩展）

- 自定义加载器注册机制。
- 热重载与版本校验。

## 9. 验收标准

- 同一数据文件在“编辑器读取”和“运行时读取”结果完全一致。
- 新增一个自定义格式仅需新增 Adapter，不改编辑器主逻辑。
- 保存后重载无行为差异。
- 所有校验规则在编辑器与运行时表现一致。

## 10. 风险与约束

- 历史 CSV 的非标准格式可能影响迁移，需要提供兼容模式。
- 旧 UI 代码对字段顺序、ID 逻辑有隐式依赖，需要梳理。
- 先稳住功能，再抽象；避免一次性重写导致可用性倒退。

## 11. 实施建议（本项目）

建议从编辑器当前文件开始最小侵入迁移：

1. `editor/modules/table_data_io.gd` 改为调用 `core/repository`。
2. `data_table_editor_panel.gd` 中 `_load_table_file/_save_table_to_file` 改为 Repository API。
3. 保留 UI 交互逻辑不动，先验证管线一致性。

