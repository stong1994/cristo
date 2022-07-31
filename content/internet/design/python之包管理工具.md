+++

date = 2022-07-31T16:14:00+08:00
title = "python之包管理工具"
url = "/internet/python/package_manager"

toc = true

+++



## 背景

学习一门语言，首先要了解的就是其包管理工具（想一想，当你打开pycharm并创建第一个python项目时，是不是要选择包管理工具🤔），而Python并不是只有一个包管理工具，因此，如何选择就成了新手们的第一个问题。

## pip

pip是通用的python包管理工具，提供了基本的包管理手段：查找、下载、卸载、更新等。

### 常用命令

1. 更新pip源：国内访问国外的网站不稳定，因此最好使用国内的源。
   1. 永久使用：`pip config set global.index-url {源地址}`
   2. 临时使用：`pip install -i {源地址} {package name} `
   3. 源地址：
      1. 阿里云：https://mirrors.aliyun.com/pypi/simple/
      2. 清华：https://pypi.tuna.tsinghua.edu.cn/simple
2. 一键导出所使用的pip包：`pip freeze > requirement.txt`
3. 一键安装所有的pip包：`pip install -r requirement.txt`
4. 查看pip安装的模块名和版本：`pip list`
5. 查看pip版本：`pip -v	`
6. 安装模块: `pip install 模块名`
7. 安装指定版本: `pip install 模块名==版本号`
8. 卸载模块: `pip uninstall 模块名`

### 缺点

pip的缺点就是对每个包一个系统只能安装一个版本，而实际项目中往往需要使用不同的版本。由此诞生了每个项目对“虚拟环境”的需求。

## Virtualenv

为每个项目分配一个独立的虚拟环境能够解决【一个系统只能安装一个版本的包】。

### 常用命令

1. 安装：`pip3 install virtualenv`
2. 搭建虚拟环境：`virtualenv venv`，可指定python解释器：`virtualenv -p /usr/bin/python3.6 venv`。
3. 激活虚拟环境：`source env/bin/activate`
4. 停用虚拟环境：`deactivate`

### 缺点

1. 每个项目使用不同的虚拟环境，每个项目也都有自己的venv文件用于存储包，如果项目多的话，包会占用相当多的磁盘空间。
2. 功能简单，只是建立虚拟环境。
3. 从操作系统的角度来看，管理virtualenv不方便，需要在各个项目下去查看（于是产生了virtualenvwrapper）。

### Virtualenvwrapper

virtualenvwrapper被用来管理virtualenv。

#### 安装

1. `pip install virtualenvwrapper`

2. `vim ~/.bashrc`开始配置virtualenvwrapper:

   ```
   export WORKON_HOME=$HOME/.virtualenvs
   source /usr/local/bin/virtualenvwrapper.sh
   ```

   使配置生效：`source ~/.bashrc(或./zshrc)`

#### 命令

- `workon`: 打印所有的虚拟环境；
- `mkvirtualenv xxx`: 创建 xxx 虚拟环境，可以--python=/usr/bin/python3.6 指定python版本;
- `workon xxx`: 使用 xxx 虚拟环境;
- `deactivate`: 退出 xxx 虚拟环境；
- `rmvirtualenv xxx`: 删除 xxx 虚拟环境。
- `lsvirtualenv` : 列举所有的环境。
- `cdvirtualenv`: 导航到当前激活的虚拟环境的目录中，比如说这样您就能够浏览它的 site-packages。
- `cdsitepackages`: 和上面的类似，但是是直接进入到 site-packages 目录中。
- `lssitepackages` : 显示 site-packages 目录中的内容。

## PipEnv

pipenv优化了Virtualenv中没有很好的满足包依赖关系的问题。

### 命令

1. 安装：`pip install pipenv`
2. 为项目创建虚拟环境：`pipenv --python 3.9.9`
3. 项目目录下会生成一个Pipfile文件，如果系统中没有 3.9.8 版本的Python，pipenv 会调用 pyenv 来安装对应的 Python 的版本。
4. 激活虚拟环境：`pipenv shell`
5. 删除虚拟环境: `pipenv --rm`
6. 安装指定依赖包: `pipenv install 软件包名称`
7. 使用国内源安装：`pipenv install --pypi-mirror https://pypi.tuna.tsinghua.edu.cn/simple 软件包名称`
8. 删除依赖包: `pipenv uninstall pytest`
9. 安装项目依赖包（项目已存在Pipfile和Pipfile.lock）：`pipenv install`(拉取最新版本的包)、`pipenv install --ignore-pipfile`（拉取Pipfile.lock中指定的版本包）
10. Pipfile.lock文件： Pipfile 中安装的包不包含包的具体版本号，而Pipfile.lock 是包含包的具体的版本号的。

### 缺点

1. 锁定文件中的包版本管理存在bug。
2. 维护者没有很好的反馈社区提供的问题。

## Poetry

作为一个“更”新的管理工具，poetry解决了pipenv存在的一些问题。

### 命令

1. 创建项目版本管理文件pyproject.toml：`poetry init`
2. 创建项目模版：`poetry new 项目名称`
3. 创建虚拟环境: `poetry install`
4. 激活虚拟环境: `poetry shell`
5. 直接在虚拟环境中执行命令：`poetry run {command}`
6. 安装包: `poetry add {package}`
7. 查看所有安装的依赖: `poetry show --tree`
8. 更新所有锁定版本的依赖: `poetry update`
9. 卸载一个包: `poetry remove {package}`

### 缺点

新的管理工具，还不是很稳定。

## PDM

作者认为pipenv和poetry都不够好用，因此开发了pdm。pdm最大的优点是：

1. 不需要安装虚拟环境
2. 拥有灵活且强大的插件系统
3. 中心化安装缓存，节省磁盘空间



## Conda

在做机器学习时，往往需要使用Anaconda，Anaconda有自己的虚拟环境系统，称为conda。

### 命令

1. 创建虚拟环境：`conda create --name environment_name python=3.6`
2. 激活虚拟环境: `conda activate`
3. conda环境的卸载: `conda remove -n environment_name --all`



## 相关阅读

- [[扯淡！Python包管理工具的发展史](https://www.cnblogs.com/Neeo/articles/10272880.html)](https://www.cnblogs.com/Neeo/articles/10272880.html#pip)
- [Pipenv vs Virtualenv vs Conda environment](https://zhuanlan.zhihu.com/p/163023998)
- [Python 包管理工具](https://juejin.cn/post/7063699409703272485#heading-9)
- [不要用 Pipenv](https://greyli.com/do-not-use-pipenv/)
- [相比 Pipenv，Poetry 是一个更好的选择](https://zhuanlan.zhihu.com/p/81025311)