# Godot Data Manager Plugin

[English](README.md) | [简体中文](README.zh-CN.md)

[![Godot v4.4](https://img.shields.io/badge/Godot-v4.4-%23478cbf)](https://godotengine.org/)
[![MIT license](https://img.shields.io/badge/license-MIT-brightgreen.svg)](../../LICENSE)
[![GitHub](https://img.shields.io/badge/GitHub-Repository-black?logo=github)](https://github.com/Liweimin0512/GDDataForge)
[![Gitee](https://img.shields.io/badge/Gitee-Repository-red?logo=gitee)](https://gitee.com/Giab/GDDataForge)

## 💡 Introduction

A flexible and efficient data management plugin designed for Godot 4.4, helping you easily manage and load game data from various file formats (CSV, JSON, etc.). Supports asynchronous loading based on thread pools, perfect for handling large amounts of game data without impacting performance. Supports direct construction of custom Resource type objects from data by defining DataType and ModelType to implement more complex data table and data model features.

## ✨ Features

- **Multiple File Format Support**

  - Support for CSV files
  - Support for JSON files
  - Extensible loader system for adding new formats

- **Flexible Data Loading**

  - Synchronous loading for simple scenarios
  - Asynchronous loading for better performance
  - Support for progress tracking and callbacks

- **Type Safety**

  - Strong type checking
  - Automatic type conversion
  - Data integrity validation system

- **Memory Efficiency**
  - Data caching system
  - Shared resource reference counting
  - Memory-optimized data structures

## 🚀 Quick Start

### Installation

1. Download or clone this repository
2. Copy the repository to your project's `addons` folder
3. Enable the plugin in Project Settings -> Plugins

### Basic Usage

#### 1. **Define Data Table Type**

```gdscript
# Create table type resource
var item_type = TableType.new(
  "item",
  ["res://data/items.csv"]
)
```

#### 2. **Model Data Mapping**

```gdscript
# Create model type resource
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

#### 3. **Load Data**

```gdscript
# Synchronous loading
DataManager.load_data_tables([table_type])

# Asynchronous loading with callback
DataManager.load_data_tables_async([table_type],
    func(results): print("Loading complete!"),
    func(current, total): print("Progress: %d/%d" % [current, total])
)
```

#### 4. **Access Data**

```gdscript
# Get item data
var item_datas = DataManager.get_table_data("items")
# Get single item data
var item_data = DataManager.get_table_item("items", "sword_1")
# Get item data model
var item : ItemModel = DataManager.get_data_model("item", "sword_1")
```

### Example Scenes

Check out the example scenes in `addons/li_data_manager/examples` to see the plugin in action:

- Data loading demonstration
- Type conversion examples
- Progress tracking
- Error handling

## 🗺️ Development Plan

- [x] Basic functionality implementation

  - [x] Extensible loader system
  - [x] Synchronous and asynchronous loading
  - [x] Data type safety
  - [x] Memory optimization

- [ ] Visual Data Editor

  - [ ] Table structure editing
  - [ ] Data entry and modification
  - [ ] Import/Export functionality
  - [ ] Preview and validation tools

- [ ] Other Features
  - [ ] Support for more file formats
  - [ ] Support for more complex data types in JSON files
  - [ ] Configurable data validation rules
  - [ ] Data compression options
  - [ ] Data encryption support
  - [ ] Data hot reloading
  - [ ] Network synchronization

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](docs/CONTRIBUTING.md) for details on how to submit pull requests, report issues, and contribute to the project.

## 📋 Code of Conduct

Please note that this project follows a [Code of Conduct](docs/CODE_OF_CONDUCT.md). By participating in this project, you agree to abide by its terms.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](/LICENSE) file for details.

## 📬 Contact

- GitHub Issues: [Issues](https://github.com/Liweimin0512/GDDataForge/issues)
- Email: [liwemin0284@gmail.com](liwemin0284@gmail.com)