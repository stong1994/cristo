+++

date = 2022-08-07T21:19:00+08:00
title = "k8s-volume"
url = "/cloudnative/k8s/configration"

toc = true

draft = true

+++

配置程序通常有三种方式：

1. 命令行参数
2. 环境变量
3. 指定配置文件

## 命令行参数

### docker中的命令参数

dockerfile中存在两个命令相关的属性：

- ENTRYPOINT：容器启动时执行的命令
- CMD：容器启动时执行的命令的参数

### 两种命令格式

- SHELL：ex，`ENTRYPOINT node app.js`
- EXEC: ex, `ENTRYPOINT ["node", "app.js"]`

两种格式的不同之处在于是否会调用shell。

以EXEC格式运行的docker，应用进程（node app.js）的PID是1；

以SHELL格式运行的docker，应用进程（node app.js）的父进程的PID为1，父进程为shell。

因此我们应该使用EXEC格式。

### k8s的命令参数

对应docker中的ENTRYPOINT和CMD，k8s中使用command和args。

example:

```yaml
kind: Pod
spec: 
	containers: 
	- image: some/image 
		command: ["/bin/command"]
    args: ["arg1", "arg2", "arg3"]
```

## 环境变量

### 在容器中的定义

```yaml
kind: Pod 
spec: 
	containers:
  - image: luksa/fortune:env
  	env: 
  	- name: INTERVAL
    	value: "30"
    name: html-generator
```

### 根据先前定义的环境变量定义环境变量

```yaml
env: 
- name: FIRST_VAR
	value: "foo"
- name: SECOND VAR
	value: "$(FIRST_VAR)bar"
```

## ConfigMap

同一个参数在不同的环境中可能不同，这种差异性不应该由pod配置来解决，k8s提供了一个统一的方式——configmap来提供配置。于是我们在不同的环境可以使用相同的pod配置。

### 多种创建方式

1. 通过命令中的字面量直接创建

   ```shell
   kubectl create configmap fortune-config --from-literal=one=1
   ```

   该命令创建的的配置key为one，value为1

2. 通过configmap配置文件直接创建

   ```shell
   kubect1 create -f fortune-config.yaml
   ```

3. 指定配置文件或目录

   ```shell
   kubectl create configmap my-config--from-file=/path/to/dir
   ```

多种创建方式example：

```shell
kubectl create configmap my-config
	--from-file-foo.json
  --from-file-bar=foobar.conf
  --from-file=config-opts/
  --from-literal=some=thing
```

![](https://raw.githubusercontent.com/stong1994/images/master/picgo/202210061624881.png)

### 使用

#### 定义为环境变量

```yaml
apiVersion: v1
kind: Pod
...
spec: 
	containers:
  - image: luksa/fortune:env
  	env: 
  	- name: INTERVAL
    	valueFrom: 
    		configMapKeyRef: 
    			name: fortune-config
          key: sleep-interval
```

批量定义：

```yaml
spec: 
	containers: 
	- image: some-image
  	envfrom: 
  	- prefix: CONFIG_
    	configMapRef: 
    		name: my-config-map
```

通过将env替换为envfrom，k8s会将configmap（my-config-map）中的键值对批量写入到环境变量中，并且附加了前缀CONFIG_

#### 定义为命令行参数

不能直接在pod.spec.containers.args中使用configmap，但是可以先将其定义为环境变量，然后在args中引用环境变量。

```yaml
spec: 
	containers: 
	- image: luksa/fortune:args
  	env:
    - name: INTERVAL
    	valueFrom: 
    		configMapKeyRef: 
    			name: fortune-config 
    			key: sleep-interval
    args: ["$(INTERVAL)"]
```

#### 定义为配置文件

```yaml
spec: 
	containers:
  - image: nginx:alpine
  	name : web-server
    volumeMounts: 
    - name: config
    	mountPath: /etc/nginx/conf.d 
    	readOnly: true
  volumes:
  - name: config
  	configMap:
    	name: fortune-config
```

将name为fortune-config的configmap中的内容写到容器的/etc/nginx/conf.d目录下。

##### 指定configmap中的实体

configmap中的每个key都是实体，使用时可以指定具体的实体。

```yaml
volumes: 
- name: config
	configMap: 
		name: fortune-config
    items:
    - key: my-nginx-config.conf
    	path: gzip.conf
```

##### 追加文件而不覆盖目录

默认情况下会直接将容器中的整个目录“覆盖”掉，可以使用subPath来指定追加文件。

```yaml
spec: 
	containers:
  - image: some/image
  	volumeMounts: 
  	- name: myvolume
    	mountPath: /etc/someconfig.conf # 指定目的文件
      subPath: myconfig.conf # 指定要挂载的文件
```

##### 指定文件权限

```yaml
volumes: 
- name: config 
	configMap: 
		name: fortune-config 
		defaultMode: "6600" # 默认为644（-rw-r-r--）
```

### 热更新

修改cofigmap

#### 配置文件

容器中的文件是一个指向具有实际数据文件的软连接。

如果将configmap中的配置以配置文件的方式挂载到容器中，一旦修改configmap，k8s会创建一个新的临时文件，并将容器中指定的文件软连接到新的临时文件。

## Secret

敏感信息往往需要加密，这时候就需要用到Secret。

Secret的使用方式和ConfigMap相似。

### 创建

提前准备好https.key https.cert等证书文件

```shell
kubectl create secret generic fortune-https 
	--from-file=https.key
  --from-file=https.cert
  --from-file=foo
```

通过以上命令创建了名为fortune-https的generic  Secret。

### 定义为环境变量

```yaml
env: 
- name: FOO_SECRET
	valueFrom:
  	secretKeyRef: 
  		name: fortune-https
      key: foo
```

### 定义为配置文件

```yaml
spec: 
	containers:
	- image: nginx:alpine 
		name : web-server 
		volumeMounts: 
		- name : certs 
			mountPath: /etc/nginx/certs/ 
			readOnly: true
	volumes:
  - name : certs 
  	secret: 
  		secretName: fortune-https
```

