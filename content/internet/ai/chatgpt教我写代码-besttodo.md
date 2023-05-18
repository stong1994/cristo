+++

date = 2023-02-26T11:30:00+08:00
title = "ChatGPT教我写代码——best todo"
url = "/internet/ai/chatgpt_best-todo"

toc = true

+++



## 前言

之前想开发一款任务管理软件，特点是将任务从紧急程度和重要程度两个角度来划分。后来发现市面上已经有了这种软件，比如forcus matrix。

![图片加载中](https://raw.githubusercontent.com/stong1994/images/master/picgo/202302191327575.png)

但是这些软件总会有些地方不太好用。所以我最终决定还是开发一个属于自己的软件。

## ChatGPT与技术选型

对一个后端boy来说，往年的开发经验很难迁移到客户端开发中，但是ChatGPT可以作为一个很耐心的老师来辅助我开发。

客户端开发选用的是flutter，主要是因为：

1. 支持跨平台，这样一次开发就能够在手机、电脑上使用。
2. 之前看过flutter的书籍，所以有一些基础。
3. 最近比较火。

由于开发过程比较顺利，所以把后端代码一起写了，语言选择的是rust，这是因为:

1. 学习rust，以前只看过书，需要实战来练手。

## 过程简述

### 聪明的ChatGPT

对于ChatGPT自然是不需要什么客套的，所以我直接问它要了一套focus matrix 的flutter实现。令我惊讶的是代码是可以直接编译运行，没有报错。下面是客户端的截图：

![](https://raw.githubusercontent.com/stong1994/images/master/picgo/202302191331046.png)

可以看到整体的功能还是很简陋的，但是大体框架已经有了。所以我需要增加一些功能，而这些功能我会让ChatGPT来完成。

接下里我让它增加了任务的编辑功能。

![](https://raw.githubusercontent.com/stong1994/images/master/picgo/202302191358754.png)

增加了背景颜色：

![](https://raw.githubusercontent.com/stong1994/images/master/picgo/202302261021330.png)

然后是增加任务弹窗、页面优化等一系列优化:

ChatGPT先是给了我弹窗的实现：

```dart
Widget _buildTaskField() {
    return TextFormField(
          controller: _textEditingController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Add a task',
          ),
          onFieldSubmitted: (value) {
            _updateTask(value);
          },
        );
  } 
```

但是不是很好看，于是我让它进行优化，下面是优化后的代码：

```dart
Widget _buildTaskField() {
  return TextFormField(
    controller: _textEditingController,
    autofocus: true,
    style: TextStyle(fontSize: 18.0, color: Colors.black87),
    decoration: InputDecoration(
      filled: true,
      fillColor: Colors.white,
      hintText: 'Add a task',
      contentPadding: EdgeInsets.symmetric(vertical: 15.0, horizontal: 15.0),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15.0),
        borderSide: BorderSide(
          width: 0.8,
          color: Colors.grey.shade400,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15.0),
        borderSide: BorderSide(
          width: 0.8,
          color: Colors.grey.shade400,
        ),
      ),
    ),
    onFieldSubmitted: (value) {
      _updateTask(value);
    },
  );
}
```

可以看到，组件中确实填充了更多的内容。

经过一系列的优化调整，最终的效果是这样的：

![](https://raw.githubusercontent.com/stong1994/images/master/picgo/202302261026212.png)

增加任务：

![](https://raw.githubusercontent.com/stong1994/images/master/picgo/202302261027842.png)

这一系列的优化可以通过[git的commit记录](https://github.com/stong1994/best_todo)来查看。

### 不太聪明的ChatGPT

1. 开发过程中，我想要在添加任务的弹窗中自动显示光标，ChatGPT提示我要用nodeFocus，但是这个解决不了，实际上，我只需要将TextField中的autofocus设置为true即可。但是由于过度信赖ChatGPT，导致花费了大量时间仍没有解决问题。

2. 过程中，当我点击了多个任务时，多个任务都会进入编辑状态，这是一个不好的体验。我让ChatGPT去解决这个问题，ChatGPT一直让我使用nodeFocus（是的，ChatGPT似乎对它情有独钟），仍旧是花费了大量时间，最终在我想起来flutter中是有事件通知(event_bus)的，并通过Google了解用法得以解决（当一个任务被编辑时通过事件告知其他处于编辑状态的任务恢复正常）。

### 学习的好帮手

在开发的过程中，我发现很多地方使用了createState，于是问它其作用，下面是ChatGPT的作用：

> 在 Flutter 中，一个 Widget 通常由三个类构成：Widget、State 和 Element，其中 Widget 用来描述组件的渲染，State 存储组件的状态和处理交互事件，而 Element 是组件的一个实例。当一个 Widget 被创建时，Flutter 会同时创建一个 State 对象和一个 Element 对象，它们三者之间是一一对应关系。
>
> 在 Stateful Widget 中，createState() 方法就是用来创建 State 对象的。当一个 Stateful Widget 被插入到 Widget 树中时，Flutter 会调用它的 createState() 方法来创建一个对应的 State 对象，并把 Widget 的配置信息传给它。这个 State 对象会被用来管理 Widget 的状态，同时它也会关联一个 Element 对象，Element 对象会被用来实现 Widget 的布局和渲染。

在 ChatGPT提供的代码中，使用了大量的Expanded，于是我问它Expanded组件的好处：

> `Expanded` widget可以将子组件在容器中进行平均分配。它会根据容器可用的空间来计算每个子组件的大小，并将它们平均分配在可用空间中。这个过程可以让布局变得更加灵活和动态。同时，如果需要调整子组件的大小比例，可以调整`Expanded`组件的`flex`属性，以控制它在可用空间中所占的比例。

### 体验小结

1. ChatGPT提供的代码中，变量名可能会变，比如任务中的是否完成，它一会用isDone，一会用isComplete。这个可以通过告知它我们用哪个来解决。
2. ChatGPT提供的代码很可能是有问题的，因此需要不断告知它报错信息，然后进一步改正。
3. ChatGPT对flutter的提示要优于rust，可能是因为rust的语法更复杂？

## ChatGPT的使用总结

1. 可以把ChatGPT视为一位全能的老师，说它是上知天文下知地理一点也不过分。
2. 不能依赖ChatGPT，有时候Google会更好用，要灵活取用。
3. ChatGPT大大降低了学习新东西的成本，就像是有师傅带和没师傅带的区别。



## 相关资料

- [客户端代码](https://github.com/stong1994/best_todo)
- [后端代码](https://github.com/stong1994/best_todo_backend)
- [Build a REST API with Rust and MongoDB - Rocket Version](https://dev.to/hackmamba/build-a-rest-api-with-rust-and-mongodb-rocket-version-ah5)