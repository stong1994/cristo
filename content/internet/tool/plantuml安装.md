+++

date = 2022-03-10T14:43:00+08:00
title = "plantuml安装"
url = "/internet/tool/plantuml"

toc = true

+++



## 1. 预安装软件

1. [Java](https://www.java.com/en/download/)
2. [Graphviz](https://plantuml.com/graphviz-dot)

Graphviz在安装过程中需要下载大量依赖包，有些会下载失败，报错如下：

````shell
==> Installing dependencies for graphviz: gts, gdk-pixbuf and librsvg
==> Installing graphviz dependency: gts
==> Pouring gts-0.7.6_2.arm64_monterey.bottle.tar.gz
🍺  /opt/homebrew/Cellar/gts/0.7.6_2: 26 files, 1.6MB
==> Installing graphviz dependency: gdk-pixbuf
==> Pouring gdk-pixbuf-2.42.8_1.arm64_monterey.bottle.tar.gz
Error: No such file or directory @ rb_sysopen - /Users/stong/Library/Caches/Homebrew/downloads/e02b07db95c1fcc05fd80893fef0e3ae95358e4b73d64bcf7048b53af47a53d9--gdk-pixbuf-2.42.8_1.arm64_monterey.bottle.tar.gz
````

这时可手动使用`brew install xx`进行下载。

依赖包比较多，因此可以使用脚本批量安装。

```shell
#!/bin/bash
array=(gts gdk-pixbuf librsvg)
for i in "${array[@]}"
do
    brew install $i
done
```

## 2. 下载plantuml

直接在[官网](https://plantuml.com/zh/download)下载pantuml的jar包即可。

## 3. 测试

1. 编写plantuml文件

   创建out.txt文件，并写入

   ```
   @startuml
   Alice -> Bob: 你好
   @enduml
   ```

2. 执行命令

   ```shell
   java -jar plantuml.jar out.txt
   ```

此时可看到新生成了out.png

![](https://raw.githubusercontent.com/stong1994/images/master/picgo/202210091050614.png)

## 4. 封装为命令

上述命令需要指定plantuml的jar包，使用不方便，可将其封装为命令。

````shell
echo "java -jar $(pwd)/plantuml.jar \$1" >> plantuml.sh
chomod +x ~/.plantuml.sh
echo 'alias plantuml="~/.plantuml.sh"' >>  ~/.zshrc
source ~/.zshrc
````

此时可在任意位置执行plantuml命令。