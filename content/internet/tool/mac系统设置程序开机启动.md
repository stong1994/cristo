---
date: 2024-06-19T10:43:00+08:00
title: "mac系统设置程序开机启动"
url: "/internet/tool/command_autorun_mac"
toc: true
draft: false
description: "mac系统设置程序开机启动"
slug: "secret book"
tags: ["笔记", "mac", "开机启动", "系统"]
showDateUpdated: true
---

## 背景

之前写了一套密码管理工具，其中包含了一个服务端。我现在将自己的mac电脑作为服务器，运行这个服务端，这样就能实现多端同步以及浏览器插件获取账号信息的功能。
可是如果每次都手动启动这个服务端，那无疑会让开机操作更加枯燥。所以还是有必要加上自动启动的。

## 实现

在mac上有两种实现方式

### Automator

1. 启用Automator.app(中文名自动操作),这是mac自带的一个工具。
2. 在左侧的侧边栏选择[资源库]-[实用工具]-[运行Shell脚本], 然后将服务脚本启动命令写入到脚本中。
   ![截图](https://raw.githubusercontent.com/stong1994/images/master/picgo/202406191619748.png)

3. 保存为APP, 然后设置为开机启动即可
   ![截图](https://raw.githubusercontent.com/stong1994/images/master/picgo/202406191639918.png)

### Launchctl

1. 在'/Library/LaunchAgents'目录下创建'xxxx.plist'文件,e.g.:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>stong.secretbookserver</string>
    <key>ProgramArguments</key>
    <array>
        <string>/xxxxxx/secret_book_server</string>
        <string>/xxxxxx/secret.db</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>

```

2. 在`ProgramArguments`中设置命令执行,比如第一个是我的服务可执行文件，第二个是服务启动所需的配置文件
3. 设置开机启动：`RunAtLoad`
4. 设置保活： `KeepAlive`
5. 加载文件：`launchctl load xxxx.plist`

## 参考文档

- [Running script upon login in mac OS X [stackoverflow]](https://stackoverflow.com/questions/6442364/running-script-upon-login-in-mac-os-x/6445525#6445525)
