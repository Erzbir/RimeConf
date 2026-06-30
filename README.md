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

1. 同步并更新子模块
2. 在每个上游子模块里执行 `git pull --ff-only origin main`
3. 记录本次 `git pull` 拉取到的文件
4. 备份这些文件会覆盖的本地文件到 `.scheme-backups/last`
5. 只复制命中 `rules` 白名单且本次 `git pull` 拉取到的上游文件

回退到上一次更新前的状态:

```sh
make restore
```

需要重新按白名单完整覆盖一次上游文件:

```sh
make update-all
```

## 自定义

修改 `*custom*` 文件
