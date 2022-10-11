+++

date = 2022-10-11T14:43:00+08:00
title = "Athens安装及使用"
url = "/internet/tool/athens"

toc = true

+++



# Athens

[官方网站](https://docs.gomods.io/)

Athens是一个go packages服务器，也就是go module的代理。

## 优势

1. 能够存储使用过的依赖库，防止维护人员对依赖库进行删除、代码变更等导致项目构建失败。
2. 作为代理访问速度要比`go get`快，`go get`是采用`git clone`的方式下载，而设置了`GOPROXY`的`go get`直接下载zip文件。
3. 能够代理私有模块

## 安装

有多种安装方式：下载源码、docker、k8s等。这里只介绍源码安装。

1. 下载源码

```
git clone https://github.com/gomods/athens
```

2. 修改配置文件

   ```
   cd athens
   mv config.dev.toml	athens.toml # 代码中默认启动的配置文件为athens.toml，之后运行代码就不用指定文件
   ```

   需要修改的配置

   | key             | value                                                        |
   | --------------- | ------------------------------------------------------------ |
   | Port            | 根据需要，默认3000                                           |
   | NETRCPath       | .netrc的地址，.netrc可以用来存储私有仓库的账号和密码         |
   | NoSumPatterns   | 私有仓库不能进行checksum验证，所以要在这里过滤掉私有仓库，比如我的测试仓库["gitlabxxx/xxx/*"] |
   | GoBinaryEnvVars | 设置GO代理相关的环境变量，因为有墙，所以需要使用其他代理，如https://goproxy.io、https://goproxy.cn等，推荐https://goproxy.cn,验证源GOSUMDB也需要使用支持国内的，这里可以设置为["GOPROXY=https://goproxy.cn,direct", "GOSUMDB=sum.golang.google.cn"] |

3. 设置私有仓库的访问权限

   1. 使用NETRAPath配置

      1. 创建.netrc文件

         ```
         # 我测试用的gitlab
         machine https://gitlabxxx/xxx # 项目匹配路径
         login xx # 账号
         password xxx # 密码
         ```

      2. 在上边的`athens.toml`配置文件中配置`NETRAPath`，值为`.netrc`地址。我的.netrc就在项目根路径，则直接设置为`./.netrc`

   2. 使用ssh替换http

      1. 生成rsa密钥`ssh-keygen`，设置私钥为id_rsa_athens，公钥存入gitlab服务

      2. 在.ssh目录下创建config文件

         ```shell
         Host gitlabxxx.com
         HostName gitlabxxx.com
         Port {gitlab服务ssh端口}
         StrictHostKeyChecking no
         IdentityFile {密钥目录}/id_rsa_athens
         ```

      3. 在gitlab上找到`user settings => Access Tokens ` 权限设置仓库只读，生成token

      4. 在服务器上执行`git config --global http.extraheader "PRIVATE-TOKEN: {Token}"`

         1. `git config --global http.extraheader "PRIVATE-TOKEN: xxxx"`

      5. 替换http为ssh `git config --global url."ssh://git@gitlabxxx.com:{端口}".insteadOf "https://gitlabxxx.com`
      
         1. `git config --global url."ssh://git@gitlabxxx.com".insteadOf "https://gitlabxxx.com"`
      
      以上两种方式选一即可。

3. 运行

   ```
   go build -o athens ./cmd/proxy
   ./athens
   ```

## Nginx设置

1. 支持https请求

2. 如果gitlab地址有端口存在，需要隐藏掉，因为go get 时会路径不能有端口

3. go get时会先请求仓库的git信息，如访问http://gitlabxxx.com/xxx/xxxx?go-get=1时，gitlab服务器返回了

```
<html><head><meta name="go-import" content="gitlabxxx.com:81/xxx/xxx git http://gitlabxxx.com:81/xxx/xxx.git" /></head></html>
```

然后比对导入的路径`http://gitlabxxx.com/xxx/xxx`会报错

```
unrecognized import path "gitlabxxx.com/xxx/xxx": parse http://gitlabxxx.com/xxx/xxx?go-get=1: no go-import meta tags (meta tag gitlabxxx.com:81/xxx/xxx did not match import path gitlabxxx.com/xxx/xxx)
```

所以需要gitlab服务器的nginx做相应的代理，即当访问`http://gitlabxxx.com/xxx/xxx`，应返回

```
<html><head><meta name="go-import" content="gitlabxxx.com/xxx/xxx git http://gitlabxxx.com:81/xxx/xxx.git" /></head></html>
```



## 使用Athens代理

1. 设置环境变量GOPROXY

   1. 直接设置为Athens代理地址

      ```
      export GOPROXY=http://goproxy.xxx.com
      ```

   2. 上边的http://goproxy.xxx.com为目前测试用的地址，为了减少自家服务器的使用，可以先访问其他官方代理，私有模块再访问自家代理

      ```
      export GOPROXY=https://goproxy.cn,http://goproxy.xxx.com
      ```

2. 设置GONOSUMDB

   1. 虽然Athens服务器设置了不对checksum进行校验，但是客户端还没有设置，因此会报错，所以要手动设置私有模块不进行校验。GOPRIVATE的值会作为GONOSUMDB的默认值，但是设置GOPRIVATE获取私有库时不会访问代理，所以要设置GONOSUMDB仅禁止校验

      ```
      export GONOSUMDB=gitlabxxx.com
      ```



## 测试

```
go get -u gitlab.com/stong1994/xxx/slicetool
```

## 问题解决记录

### 1. 拉取私有仓库报错

```shell
fatal: could not read Username for 'https://gitlabxxx.com': terminal prompts disabled
```

解决方案：

1. 开启并输入账号密码

   ```shell
   env GIT_TERMINAL_PROMPT=1 go get gitlabxxx.com/xxx/xxxx@v1.2.1
   ```

2. 设置为ssh连接

   ```shell
   git config --global --add url."git@gitlabxxx.com:".insteadOf "https://gitlabxxx.com/"
   ```

   

## 相关文档

• https://www.cnblogs.com/laud/p/athens.html