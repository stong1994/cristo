+++

date = 2022-10-16T21:19:00+08:00
title = "k8s-ServiceAccount&RBAC"
url = "/cloudnative/k8s/serviceAccount_rbac"

toc = true

draft = false

+++

## ServiceAccount

k8s中管理pod的访问权限的实体是ServiceAccount。

### 分组

为一批用户绑定一个分组，能够实现用户和权限之间的解耦。

内置的分组：

- `system:unauthenticated`: 适用于无需任何权限校验的请求
- `system:authenticated`: 适用于权限认证已通过的请求
- `system:serviceaccounts`:  包含系统中所有的ServiceAccount
- `system:serviceaccounts:<namespace>`: 包含指定命名空间的所有ServiceAccount

example：

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: curl-custom-sa
spec:
  serviceAccountName: foo
  containers:
  - name: main
    image: tutum/curl
    command: ["sleep", "9999999"]
  - name: ambassador
    image: luksa/kubectl-proxy:1.6.2
```



## RBAC

ROLE BASE ACCESS CONTROL

### RBAC鉴权插件

RBAC鉴权插件用于检查是否允许用户执行某行为。

RBAC鉴权插件通过引入角色来解耦用户和权限，用户不绑定权限，而是绑定角色，角色绑定权限。

### RBAC资源

RBAC鉴权插件中的角色是一种资源，这种资源分成四种：

- Role和ClusterRole：指定动作能够用于哪些资源。
- RoleBinding和ClusterRoleBinding: 绑定上述角色到特定的用户、组以及ServiceAccount。

**Role和RoleBinding是namespace级别的资源，而ClusterRole和ClusterRoleBinding是集群级别的资源。除此之外，Role不能指定非资源类的url，而ClusterRole可以。**

![](https://raw.githubusercontent.com/stong1994/images/master/picgo/202210152058567.png)

### 动词

访问API server是通过HTTP进行访问，而控制访问则是通过动词实现的。因此动词对应于HTTP的方法：

| HTTP 方法 | 单个资源动词                 | 多资源动词       |
| --------- | ---------------------------- | ---------------- |
| GET, HEAD | get (and watch for watching) | list (and watch) |
| POST      | create                       | n/a              |
| PUT       | update                       | n/a              |
| PATCH     | patch                        | n/a              |
| DELETE    | delete                       | deletecollection |



### Example

#### 创建只读Role

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: foo # role需要指定namespace
  name: service-reader
rules:
- apiGroups: [""] # 指定apiGroup为空
  verbs: ["get", "list"] # 指定动词
  resources: ["services"] # 指定资源，必须使用复数
```

应用上述配置会生成一个名为service-reader的在foo命名空间下用于空的apiGroup且get和list动词的所有资源。

#### 绑定Role到ServiceAccount

1. 通过声明文件：

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: test
  namespace: foo
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: service-reader
subjects:
- kind: ServiceAccount
  name: default
  namespace: foo
```

2. 通过命令：

```shell
kubectl create rolebinding test --role=service-reader --serviceaccount=foo:default -n foo
```

在foo命名空间下创建一个名为test的RoleBinding，并绑定名为service-reader的Role与名为default的ServiceAccount。

![](https://raw.githubusercontent.com/stong1994/images/master/picgo/202210152056911.png)

### 四种角色资源的使用

| 访问                                                         | 角色类型    | 绑定类型           |
| ------------------------------------------------------------ | ----------- | ------------------ |
| 集群级别的资源，如节点、持久卷                               | ClusterRole | ClusterRoleBinding |
| 非资源类url，如/health                                       | ClusterRole | ClusterRoleBinding |
| 在任意namespace使用namespaced资源                            | ClusterRole | ClusterRoleBinding |
| 在特定namespace使用namespaced资源(多个namespace使用同一个ClusterRole) | ClusterRole | RoleBinding        |
| 在特定namespace使用namespaced资源(各个namespace各自定义Role) | Role        | RoleBinding        |

