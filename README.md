主要方案来源:

- 中文: [rime-ice](https://github.com/iDvel/rime-ice)
- 日文: [rime-kagiroi](https://github.com/rimeinn/rime-kagiroi)

默认启用两个方案:

- `double_pinyin_flypy`: 小鹤双拼

  > 取消了中英混输以及拆字

- `kagiroi`: 日文

常用快捷键:

- `Control+grave`: 打开方案菜单
- `Control+Shift+C`: 在中文和日文方案之间切换

## 目录说明

- `rules/`: 从上游方案同步文件时使用的 rsync 规则
- `packages/`: 上游方案子模块

## 更新

```sh
make update
```

`make update` 会执行:

1. 备份即将被覆盖的文件到 `.scheme-backups/last`
2. 同步并更新子模块
3. 按 `rules` 中的的白名单复制上游文件

回退到上一次更新前的状态:

```sh
make restore
```

## 自定义

修改 `*custom*` 文件
