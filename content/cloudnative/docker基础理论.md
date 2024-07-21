+++

date = 2022-10-22T21:19:00+08:00
title = "docker基础理论"
url = "/cloudnative/docker/base"

tags = ["云原生", "Docker"]
toc = true

draft = false

+++

## 背景

Docker的兴起在于其解决了在Pass平台上打包十分繁琐的问题：Pass平台需要在一个虚拟机上启动来自多个不同用户的应用，而不同的应用所依赖的语言、框架、环境都不同，因此管理这些应用的依赖是非常棘手的问题。

Docker解决这一问题的方式就是使用Docker镜像。镜像由一个完整操作系统的所有文件和目录构成，因此镜像提供者需要将自己应用所依赖的所有东西都打包到这个镜像，这避免了Pass平台自己来维护这些依赖，并且能够保证由镜像构建出来的应用不论是在本地开发还是测试环境都是同样的效果。

## 核心功能

> 容器的核心功能，就是通过约束和修改进程的动态表现，为其创造一个”边界“

这个“边界”的能力包括对进程的视图隔离和资源限制，分别对应Linux上的Namespaces技术和Cgroups技术。

### Namespaces-视图隔离

Linux操作系统提供了一系列的Namespace，包括：PID、Mount、UTS、IPC、Network、User。

以PID为例，Linux系统在创建进程时在参数中指定CLONE_NEWPID，那么新建的进程就会看到一个全新的进程空间，在这个空间里，没有其他的进程，该进程本身的PID为1.当然，这只是一个障眼法，在宿主机中执行ps命令就能看到其真实的PID。

查看容器中的PID：

```sh
$ docker run -it busybox /bin/sh
/ # ps
PID   USER     TIME  COMMAND
    1 root      0:00 /bin/sh
    7 root      0:00 ps
```

在宿主机查看容器的PID:

```sh
$ ps aux | grep busybox
xxx            22834   0.0  0.0 408628368   1648 s003  S+    9:39PM   0:00.00 grep --color=auto --exclude-dir=.bzr --exclude-dir=CVS --exclude-dir=.git --exclude-dir=.hg --exclude-dir=.svn --exclude-dir=.idea --exclude-dir=.tox busybox
xxx            22438   0.0  0.2 409266240  35632   ??  S     9:31PM   0:00.12 /usr/local/bin/com.docker.cli run -it busybox /bin/sh
xxx            22437   0.0  0.2 409280112  37104   ??  S     9:31PM   0:00.09 docker run -it busybox /bin/sh
```

通过这个例子即可明白，**容器本质上就是一个进程**，用户的应用进程就是容器里PID为1的进程，也是其他后续创建的所有进程的父进程。

### Cgroups-资源限制

在Linux中，Cgroups向用户暴露出来的操作接口是文件系统，可查看`/sys/fs/cgroup`下的文件:

```shell
$ ll /sys/fs/cgroup/
total 0
dr-xr-xr-x 5 root root  0 Feb 17  2022 blkio
lrwxrwxrwx 1 root root 11 Feb 17  2022 cpu -> cpu,cpuacct
lrwxrwxrwx 1 root root 11 Feb 17  2022 cpuacct -> cpu,cpuacct
dr-xr-xr-x 2 root root  0 Feb 17  2022 cpu,cpuacct
dr-xr-xr-x 2 root root  0 Feb 17  2022 cpuset
dr-xr-xr-x 5 root root  0 Feb 17  2022 devices
dr-xr-xr-x 2 root root  0 Feb 17  2022 freezer
dr-xr-xr-x 2 root root  0 Feb 17  2022 hugetlb
dr-xr-xr-x 5 root root  0 Feb 17  2022 memory
lrwxrwxrwx 1 root root 16 Feb 17  2022 net_cls -> net_cls,net_prio
dr-xr-xr-x 2 root root  0 Feb 17  2022 net_cls,net_prio
lrwxrwxrwx 1 root root 16 Feb 17  2022 net_prio -> net_cls,net_prio
dr-xr-xr-x 2 root root  0 Feb 17  2022 perf_event
dr-xr-xr-x 5 root root  0 Feb 17  2022 pids
dr-xr-xr-x 2 root root  0 Feb 17  2022 rdma
dr-xr-xr-x 5 root root  0 Feb 17  2022 systemd
```

也可通过mount命令来显示：

```shell
$ mount -t cgroup
cgroup on /sys/fs/cgroup/systemd type cgroup (rw,nosuid,nodev,noexec,relatime,xattr,release_agent=/usr/lib/systemd/systemd-cgroups-agent,name=systemd)
cgroup on /sys/fs/cgroup/cpuset type cgroup (rw,nosuid,nodev,noexec,relatime,cpuset)
cgroup on /sys/fs/cgroup/blkio type cgroup (rw,nosuid,nodev,noexec,relatime,blkio)
cgroup on /sys/fs/cgroup/hugetlb type cgroup (rw,nosuid,nodev,noexec,relatime,hugetlb)
cgroup on /sys/fs/cgroup/pids type cgroup (rw,nosuid,nodev,noexec,relatime,pids)
cgroup on /sys/fs/cgroup/rdma type cgroup (rw,nosuid,nodev,noexec,relatime,rdma)
cgroup on /sys/fs/cgroup/perf_event type cgroup (rw,nosuid,nodev,noexec,relatime,perf_event)
cgroup on /sys/fs/cgroup/memory type cgroup (rw,nosuid,nodev,noexec,relatime,memory)
cgroup on /sys/fs/cgroup/devices type cgroup (rw,nosuid,nodev,noexec,relatime,devices)
cgroup on /sys/fs/cgroup/cpu,cpuacct type cgroup (rw,nosuid,nodev,noexec,relatime,cpu,cpuacct)
cgroup on /sys/fs/cgroup/net_cls,net_prio type cgroup (rw,nosuid,nodev,noexec,relatime,net_cls,net_prio)
cgroup on /sys/fs/cgroup/freezer type cgroup (rw,nosuid,nodev,noexec,relatime,freezer)
```

可以看到`/sys/fs/cgroup`下有很多目录，也可以称其为子系统。

查看cpu子系统的配置文件：

```shell
-rw-r--r-- 1 root root 0 Oct 22 20:57 cgroup.clone_children
-rw-r--r-- 1 root root 0 Feb 17  2022 cgroup.procs
-r--r--r-- 1 root root 0 Oct 22 20:57 cgroup.sane_behavior
-r--r--r-- 1 root root 0 Oct 22 20:57 cpuacct.stat
-rw-r--r-- 1 root root 0 Oct 22 20:57 cpuacct.usage
-r--r--r-- 1 root root 0 Oct 22 20:57 cpuacct.usage_all
-r--r--r-- 1 root root 0 Oct 22 20:57 cpuacct.usage_percpu
-r--r--r-- 1 root root 0 Oct 22 20:57 cpuacct.usage_percpu_sys
-r--r--r-- 1 root root 0 Oct 22 20:57 cpuacct.usage_percpu_user
-r--r--r-- 1 root root 0 Oct 22 20:57 cpuacct.usage_sys
-r--r--r-- 1 root root 0 Oct 22 20:57 cpuacct.usage_user
-rw-r--r-- 1 root root 0 Oct 22 20:57 cpu.cfs_period_us
-rw-r--r-- 1 root root 0 Oct 22 20:57 cpu.cfs_quota_us
-rw-r--r-- 1 root root 0 Oct 22 20:57 cpu.rt_period_us
-rw-r--r-- 1 root root 0 Oct 22 20:57 cpu.rt_runtime_us
-rw-r--r-- 1 root root 0 Oct 22 20:57 cpu.shares
-r--r--r-- 1 root root 0 Oct 22 20:57 cpu.stat
-rw-r--r-- 1 root root 0 Oct 22 20:57 notify_on_release
-rw-r--r-- 1 root root 0 Oct 22 20:57 release_agent
-rw-r--r-- 1 root root 0 Oct 22 20:57 tasks
```

这些配置文件即资源的控制配置。

在`/sys/fs/cgroup/cpu`下创建一个目录就是创建一个控制组。

```shell
$ mkdir container
$ ls container/
cgroup.clone_children  cpuacct.usage_percpu_sys   cpu.rt_period_us
cgroup.procs           cpuacct.usage_percpu_user  cpu.rt_runtime_us
cpuacct.stat           cpuacct.usage_sys          cpu.shares
cpuacct.usage          cpuacct.usage_user         cpu.stat
cpuacct.usage_all      cpu.cfs_period_us          notify_on_release
cpuacct.usage_percpu   cpu.cfs_quota_us           tasks
```

可以看到会自动在文件下生成配置文件。

执行脚本来使用cpu

```shell
$ while : ; do : ; done &
[1] 110625
```

通过top命令可以看到cpu已跑满。

查看配置文件，发现没有对cpu做任何限制。

```shell
$ cat /sys/fs/cgroup/cpu/container/cpu.cfs_quota_us
-1
$ cat /sys/fs/cgroup/cpu/container/cpu.cfs_period_us
100000
```

修改cpu的资源限制，并将脚本进程写入tasks文件

```sh
$ echo 20000 > /sys/fs/cgroup/cpu/container/cpu.cfs_quota_us
$ echo 110625 > /sys/fs/cgroup/cpu/container/tasks
```

再次通过top命令查看，发现cpu资源目前只使用了20%。

通过这个例子即可明白，通过在子系统目录上添加配置即可实现对容器进程的资源限制。

### 层级镜像

镜像提供了对容器的封装能力。对于一个镜像来说，往往需要很多文件组成。而不同的镜像又往往包含大量相同的文件，因此复用这些文件能够减轻存储上的负担。

#### aufs

Docker使用了联合文件系统（UnionFS）来将不同位置的文件挂在到同一个目录下。如：

```shell
$ mkdir A
$ touch A/a
$ touch A/x
$ mkdir B
$ touch B/b
$ touch B/x
$ tree .
.
├── A
│   ├── a
│   └── x
└── B
    ├── b
    └── x

$ mkdir C
$ mount -t aufs -o dirs=./A:./B none ./C
$ tree ./C
├── C
    ├── a
 		├── b
    └── x
```

_aufs目前未进入Linux内核主干，因此需要在Ubuntu或者Debian中使用。_

查看一个真实的镜像的rootfs：mongo:latest

```shell
$ docker image inspect mongo:latest
...
	"RootFS": {
            "Type": "layers",
            "Layers": [
                "sha256:9beca9c8e2ecd104c677c9641a49185b9f8378ea324deb0fe9cf27110b1b6d63",
                "sha256:9b15e449fc8674321a15ba2a95524c97ab7d00100e455557e62710fa523cf18d",
                "sha256:cd29c6aca3eace87b2f1fa23298091b08ef0690bebae3057800ed850905e4a40",
                "sha256:16208120a67a2d53b08746d1e2247509610deaec5b7171679d34271d57a93acd",
                "sha256:1086bc23cfe49c43bb9b3dd087c779a12a2b2a67cd5fbf122c0e6920686057b6",
                "sha256:ef164b7459da57e99f803812c147ece267bea290adbf46dbeac3a24d58aff884",
                "sha256:88258f62562c3cae2688d5fbee79558f3fedd801e3a3d07bf269030b5a17908e",
                "sha256:fed744844078c1ba0e96a9485b700a5a37582f15fe04e7f116b717f5783db491",
                "sha256:7a9de8ac1cd283c2a7ecc7f336bc0b31302955d5c13b780745db57e96f663dc3"
            ]
        },
...
```

可以看到这个镜像由9个层组成。

#### 只读层

一个容器的rootfs可以分为三类：只读层、可读写层和Init层。其中只读层就对应于其镜像包含的层。

#### Init层

只读层上边是Init层，是Docker用来存储/etc/hosts、/etc/resolv.conf 等信息的。

修改这层的内容只对当前容器有效，在docker commit时，不会包含Init层。

#### 可读写层

可读写层是这个容器的rootfs最上面的一层，在容器里边的写操作都会以增量的方式出现在该层中。

如果是删除操作，则会创建一个名为.wh.foo的文件并将此内容写到这个文件中，用于遮挡该内容。

当docker commit时，可读写层会被提交。
