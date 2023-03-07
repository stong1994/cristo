+++

date = 2023-03-07T20:00:00+08:00
title = "详解flutter中的setState"
url = "/internet/flutter/setstate"

toc = true

+++

## 什么是setState

在Flutter中，Widget的状态是不可变的，因此，当您需要更新Widget的状态时，您需要调用setState方法来通知Flutter框架重新构建Widget。

当调用 `setState` 方法时，Flutter 框架会重新调用当前组件的 `build` 方法，生成新的 `Widget` 树，并将其与之前的 `Widget` 树进行比较，然后更新有差异的部分。

## 一个最简单的例子：计算器

```dart
class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

这里每点击一次按钮，就会在setState中增加一次counter，然后setState就会重新构建UI，所以我们就会看到计数器实时更新。

## 思考1: _counter++在setState外会如何？

将代码改为：

```dart
void _incrementCounter() {
  _counter++;
  setState(() {
  });
}
```

效果依旧。

因为组件中的元素改变了。**setState的作用只是通知作用——通知框架重新构建Widget树。**

## 思考2：如果数据来源不在内存中，而是api接口呢？

模拟api调用：

```
int count = 0;

class api {
  static Future<int> getCounter() async {
    await Future.delayed(Duration(seconds: 1));
    return count;
  }

  static incre() async {
    await Future.delayed(Duration(seconds: 1));
    count += 1;
  }
}
```

修改代码：

```dart
class _MyHomePageState extends State<MyHomePage> {
  void _incrementCounter() {
    setState(() {
      api.incre(); // 这里修改
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: FutureBuilder<int>( // 这里修改
          future: api.getCounter(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }
            if (snapshot.hasError) {
              return Center(
                child: Text("Error: ${snapshot.error}}"),
              );
            }
            int? ct = snapshot.data;
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const Text(
                    'You have pushed the button this many times:',
                  ),
                  Text(
                    '$ct', // 这里修改
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ],
              ),
            );
          }),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

可以看到效果正常。

**这是因为在使用动态生成的组件（例子中的FutureBuilder）时，即使组件的状态没有发生改变，flutter框架仍会根据最新的State对象重建Widget树，并使用最新的数据更新动态生成的组件。**

这段代码有个问题，那就是incre方法是异步的，setState可不会等到incre执行完才结束。

修改等待时间：

```dart
int count = 0;

class api {
  static Future<int> getCounter() async {
    await Future.delayed(Duration(milliseconds: 200));
    return count;
  }

  static incre() async {
    await Future.delayed(Duration(seconds: 1));
    count += 1;
  }
}
```

再次构建就会发现，点击按钮不一定会生效。这是因为得到setState的通知后，在数据更新之前UI已经重新构建完毕。所以正确的写法是使用`then()`方法来触发：

```dart
void _incrementCounter() {
  api.incre().then((_) {
  	setState(() {});
  });
}
```

构建后可以看到，点击按钮之后1秒才开始重新构建UI，这是因为incre休眠了1秒。

## 思考3：如果数据没变化，会重新构建UI吗？

验证方法：重新构建时，会调用build方法，因此在build时打印日志即可。

```dart
@override
  Widget build(BuildContext context) {
    print('building...');
    return Scaffold(
      。。。
```

然后将更新数据的代码注释：

```dart
void _incrementCounter() {
    setState(() {
      // _counter++;
    });
  }
```

再试构建，点击按钮，发现即使数据没有变化，依然进行了构建。

**setState方法会将该Widget标记为"dirty"，Flutter框架在下一帧的UI构建周期中会检测到该Widget的dirty标记，并在进行UI绘制时重新构建该Widget**。

在这个例子中，尽管_counter值没有更新，但在调用setState之后，Flutter框架仍会将MyHomePage Widget标记为dirty，以便在下一帧UI构建周期中重新绘制。

## setState重新构建UI的条件

当你调用 `setState()` 方法时，Flutter 框架会将当前组件的状态标记为“脏状态”，这表示组件的状态已经发生了变化，并需要在下一帧（frame）中进行更新。Flutter 框架将在下一帧中执行以下操作：

1. 重建当前组件及其子组件的 Widget 树，以反映最新的状态。
2. 生成新的 RenderObject 树，并将其与 Widget 树进行匹配，以生成新的 RenderTree。
3. 使用新的 RenderTree 来更新屏幕上的实际像素。

因此，当你调用 `setState()` 方法时，会触发 Widget 树的重建，并根据最新的 State 对象更新组件的状态和视图。以下是 `setState()` 方法触发 Widget 树重建的条件：

1. 当前组件的状态已经发生了变化，并且你想将最新的状态反映到视图中。
2. 当前组件的子组件的状态已经发生了变化，并且你想更新子组件的状态和视图。
3. 当前组件的父组件的状态已经发生了变化，并且你想更新当前组件及其子组件的状态和视图。
4. 当前组件的父组件的父组件的状态已经发生了变化，并且你想更新当前组件及其祖先组件的状态和视图。

需要注意的是，虽然调用 `setState()` 方法会触发 Widget 树的重建，但并不意味着所有的子组件都会被重建。Flutter 框架会尽可能地复用已经存在的 Widget 和 RenderObject，以最大限度地提高性能。因此，在实际开发中，你需要注意哪些组件会被重建，以及如何优化组件的重建，以提高应用程序的性能。

## 重构UI时的复用逻辑

在 Flutter 中，当一个组件的状态发生变化，需要重新构建该组件及其子组件时，Flutter 框架会尝试复用已经存在的 Widget 和 RenderObject。具体的逻辑如下：

1. 如果新旧状态对象相同，则认为组件的状态没有发生变化，不需要重新构建该组件及其子组件。
2. 如果新旧状态对象不同，则判断组件的类型是否相同。
   - 如果组件类型不同，则无法复用现有的 Widget 和 RenderObject，需要销毁现有的 Widget 和 RenderObject，并重新创建新的 Widget 和 RenderObject。
   - 如果组件类型相同，则尝试复用现有的 Widget 和 RenderObject。
3. 首先，Flutter 框架会比较新旧 Element 的类型和 key 是否相同，如果不同，则认为无法复用现有的 Element，需要销毁现有的 Widget 和 RenderObject，并重新创建新的 Widget 和 RenderObject。
4. 如果新旧 Element 的类型和 key 相同，则尝试复用现有的 Element。
5. 首先，Flutter 框架会将新旧 Element 的 Widget 树进行比较，找到不同的节点，并将它们从 RenderObject 树中删除。
6. 然后，Flutter 框架会将新旧 Element 的 Widget 树进行比较，找到不同的节点，并将它们添加到 RenderObject 树中。
7. 最后，Flutter 框架会将新的 Widget 树和 RenderObject 树与旧的 Widget 树和 RenderObject 树进行比较，找到相同的节点，并将新的 Widget 和 RenderObject 对应到旧的 Widget 和 RenderObject 上，从而完成复用。

需要注意的是，在复用现有的 Widget 和 RenderObject 时，Flutter 框架会尽可能地复用现有的对象，以减少不必要的资源开销。但是，如果现有的 Widget 和 RenderObject 无法满足新的需求，则需要销毁现有的对象，并重新创建新的对象。因此，在实际开发中，你需要注意如何优化组件的复用，以提高应用程序的性能。



## 示例代码

https://github.com/stong1994/flutter_practise/tree/master/set_state
