# GDDataForge Editor Modules

本目录用于承载可视化数据编辑器的可复用模块，目标是让 `data_table_editor_panel.gd` 保持为“状态编排器”，而不是“大而全逻辑文件”。

## 模块职责

- `table_dialog_controller.gd`
  - 负责创建弹窗与读取表单数据（新建表、添加行/列/外键）。

- `table_edit_actions.gd`
  - 负责行列外键编辑动作的纯逻辑（校验、构造、批量变更）。

- `table_view_controller.gd`
  - 负责搜索/过滤/排序与 `Tree` 视图渲染。

- `table_validation_controller.gd`
  - 负责字段校验规则 UI 动态构建与数据校验执行。

- `table_data_io.gd`
  - 负责 CSV/JSON 的解析与保存。

- `table_editor_utils.gd`
  - 负责通用工具（标识符校验、目录创建、类型转换、模板文件创建）。

## 依赖方向建议

为避免循环依赖，建议保持单向依赖：

`data_table_editor_panel.gd` -> `modules/*`

并尽量避免模块之间相互调用；若必须调用，优先通过参数传入数据/回调而非直接引用编辑器节点。

## 维护约定

- 模块尽可能保持“无状态”或“轻状态”。
- UI 节点查找与信号绑定尽量留在主编辑器中。
- 新增功能优先放入对应模块，再在主编辑器接线。
