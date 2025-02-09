# Godot 数据管理器插件

[English](README.md) | [简体中文](README.zh-CN.md)

[![Godot v4.4](https://img.shields.io/badge/Godot-v4.4-%23478cbf)](https://godotengine.org/)
[![MIT license](https://img.shields.io/badge/license-MIT-brightgreen.svg)](../../LICENSE)
[![GitHub](https://img.shields.io/badge/GitHub-仓库-black?logo=github)](https://github.com/Liweimin0512/GDDataForge)
[![Gitee](https://img.shields.io/badge/Gitee-仓库-red?logo=gitee)](https://gitee.com/Giab/GDDataForge)

## 💡 简介

一个为 Godot 4.4 设计的灵活高效的数据管理插件，帮助您轻松管理和加载来自各种文件格式（CSV、JSON等）的游戏数据。支持同步和异步加载，非常适合处理大量游戏数据而不影响性能。

## ✨ 特性

- **多文件格式支持**
  - 支持 CSV 文件
  - 支持 JSON 文件
  - 可扩展的加载器系统，方便添加新格式

- **灵活的数据加载**
  - 同步加载用于简单场景
  - 异步加载提供更好性能
  - 支持进度跟踪和回调

- **类型安全**
  - 强类型检查
  - 自动类型转换
  - 数据完整性验证系统

- **内存效率**
  - 数据缓存系统
  - 共享资源引用计数
  - 内存优化的数据结构

## 🚀 快速开始

### 安装

1. 下载或克隆此仓库
2. 将 `addons/li_data_manager` 文件夹复制到你项目的 `addons` 文件夹中
3. 在项目设置 -> 插件中启用此插件

### 基本用法

1. **定义数据表类型**
```gdscript
# 创建表格类型资源
var item_type = TableType.new(
  "item",
  ["res://data/items.csv"]
)
```

2. **模型数据映射**
```gdscript
# 创建模型类型资源
class ItemModel: 
  extends Resource
  var id: String
  var name: String

var item_model_type = ModelType.new(
    "item",
    "res://scripts/item_model.gd",
    item_type,
)
```

3. **加载数据**
```gdscript
# 同步加载
DataManager.load_data_tables([table_type])

# 异步加载带回调
DataManager.load_data_tables_async([table_type],
    func(results): print("加载完成！"),
    func(current, total): print("进度:%d/%d" % [current, total])
)
```

4. **访问数据**
```gdscript
# 获取物品数据
var item_datas = DataManager.get_table_data("items")
# 获取单个物品数据
var item_data = DataManager.get_table_item("items", "sword_1")
# 获取物品数据模型
var item : ItemModel = DataManager.get_data_model("item", "sword_1")
```

### 示例场景

查看 `addons/li_data_manager/examples` 中的示例场景，了解插件的实际应用：
- 数据加载演示
- 类型转换示例
- 进度跟踪
- 错误处理

## 🗺️ 开发计划

- [x] 基本功能实现
  - [x] 可拓展的加载器系统
  - [x] 同步加载和异步加载
  - [x] 数据类型安全
  - [x] 内存优化

- [ ] 可视化数据编辑器
  - [ ] 表格结构编辑
  - [ ] 数据录入和修改
  - [ ] 导入导出功能
  - [ ] 预览和验证工具

- [ ] 其他功能
  - [ ] 更多文件格式支持
  - [ ] json文件支持更多复杂数据类型
  - [ ] 可配置的数据校验规则
  - [ ] 数据压缩选项
  - [ ] 数据加密支持
  - [ ] 网络同步

## 🤝 参与贡献

欢迎参与贡献！您可以：

1. Fork 这个仓库
2. 创建您的特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交您的更改 (`git commit -m '添加一些很棒的功能'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启一个 Pull Request

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](/LICENSE) 文件了解详情。

## 📬 联系方式

- GitHub Issue 追踪：[Issues](https://github.com/Liweimin0512/GDDataForge/issues)
- 邮箱：[liwemin0284@gmail.com](liwemin0284@gmail.com)
