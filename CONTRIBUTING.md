# 参与贡献

感谢参与 SecondSalary。提交问题或代码前，请先确认变更符合“本地、轻量、无付费依赖”的项目方向。

## 开发要求

- macOS 13 或更高版本
- Xcode 26 推荐
- Swift 6 严格并发检查
- 不新增第三方运行时依赖，除非先在 Issue 中说明必要性与维护成本
- 用户可见文案使用简体中文
- 不添加网络、遥测或数据收集能力

## 代码约定

- 业务计算与 SwiftUI 视图分离
- 共享可变状态保持在主线程隔离的状态层中
- 金额计算使用 `Decimal`，不要使用格式化后的字符串参与计算
- 计数结果由时间差推导，不逐秒累加并持久化金额
- 新增图标或插图必须确认许可，不把 SF Symbols 用作应用图标或商标
- 新增用户行为时同时补充单元测试和 README

## 提交前检查

```sh
xcodebuild \
  -project SecondSalary.xcodeproj \
  -scheme SecondSalary \
  -configuration Debug \
  -derivedDataPath /tmp/SecondSalaryDerived \
  test
```

请同时手动验证菜单栏显示、开始和结束搬砖、设置保存以及睡眠后的状态。

## 许可证

提交贡献即表示你同意按仓库的 GNU GPL v3.0 only 许可证发布贡献内容。
