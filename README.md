# Data Manager Plugin for Godot

[English](README.md) | [简体中文](README.zh-CN.md)

[![Godot v4.4](https://img.shields.io/badge/Godot-v4.4-%23478cbf)](https://godotengine.org/)
[![MIT license](https://img.shields.io/badge/license-MIT-brightgreen.svg)](../../LICENSE)
[![GitHub](https://img.shields.io/badge/GitHub-Repository-black?logo=github)](https://github.com/Liweimin0512/GDDataForge)
[![Gitee](https://img.shields.io/badge/Gitee-Repository-red?logo=gitee)](https://gitee.com/Giab/GDDataForge)

## 💡 Introduction

A flexible and efficient data management plugin for Godot 4.4, designed to help you easily manage and load game data from various file formats (CSV, JSON, etc.). It supports both synchronous and asynchronous loading, making it perfect for handling large amounts of game data without impacting performance.

## ✨ Features

- **Multiple File Format Support**
  - CSV file support
  - JSON file support
  - Extensible loader system for adding new formats

- **Flexible Data Loading**
  - Synchronous loading for simple use cases
  - Asynchronous loading for better performance
  - Progress tracking and callback support

- **Type Safety**
  - Strong type checking for data fields
  - Automatic type conversion
  - Validation system for data integrity

- **Memory Efficient**
  - Data caching system
  - Reference counting for shared resources
  - Memory-optimized data structures

## 🚀 Getting Started

### Installation

1. Download or clone this repository
2. Copy the `addons/li_data_manager` folder to your project's `addons` folder
3. Enable the plugin in Project Settings -> Plugins

### Basic Usage

1. **Define Your Data Table Type**
```gdscript
# Create a table type resource
var table_type = TableType.new()
table_type.table_name = "items"
table_type.table_paths = ["res://data/items.csv"]
```

2. **Load Data**
```gdscript
# Synchronous loading
DataManager.load_data_tables([table_type])

# Asynchronous loading with callbacks
DataManager.load_data_tables_async([table_type],
    func(results): print("Loading completed!"),
    func(current, total): print("Progress: %d/%d" % [current, total])
)
```

3. **Access Data**
```gdscript
# Get item data
var item_data = DataManager.get_table_data("items")
```

### Example Scene

Check out the example scene in `addons/li_data_manager/examples` to see the plugin in action:
- Data loading demonstration
- Type conversion examples
- Progress tracking
- Error handling

## 🗺️ Roadmap

- [ ] Visual Data Editor
  - Table structure editing
  - Data entry and modification
  - Import/Export functionality
  - Preview and validation tools

- [ ] Additional Features
  - More file format support
  - Data compression options
  - Data encryption support
  - Network synchronization

## 🤝 Contributing

Contributions are welcome! Feel free to:

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 📬 Contact

- GitHub Issue Tracker: [Issues](https://github.com/Liweimin0512/GDDataForge/issues)
- Email: [liwemin0284@gmail.com](liwemin0284@gmail.com)