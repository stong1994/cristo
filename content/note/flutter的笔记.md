---
title: "rust待整理笔记"
date: 2023-02-20T14:35:00+08:00
url: "/note/rust/todo"
isCJKLanguage: true
draft: true
toc:  true
keywords:
  - rust
authors:
  - stong
---



setState中body为空，那么就不会刷新页面吗

> 如果 `setState` 方法中的 `build` 方法返回的 `body` 为空，那么页面不会出现任何内容，也就无法刷新页面。
>
> 具体来说，当调用 `setState` 方法时，Flutter 框架会重新调用当前组件的 `build` 方法，生成新的 `Widget` 树，并将其与之前的 `Widget` 树进行比较，然后更新有差异的部分。如果 `build` 方法返回的 `Widget` 为 `null`，则新的 `Widget` 树中不会有任何内容需要更新，因此页面也不会刷新。
>
> ```
> class MyWidget extends StatefulWidget {
>   @override
>   _MyWidgetState createState() => _MyWidgetState();
> }
> 
> class _MyWidgetState extends State<MyWidget> {
>   int _count = 0;
> 
>   void _incrementCount() {
>     setState(() {
>       _count++;
>     });
>   }
> 
>   @override
>   Widget build(BuildContext context) {
>     return Scaffold(
>       body: _count % 2 == 0 ? null : Center(child: Text('Count: $_count')),
>       floatingActionButton: FloatingActionButton(
>         onPressed: _incrementCount,
>         child: Icon(Icons.add),
>       ),
>     );
>   }
> }
> 
> ```
>
> 在这个例子中，我们创建了一个有状态的组件 `MyWidget`，其中包含一个计数器 `_count` 和一个 `FloatingActionButton`，每次点击按钮都会调用 `_incrementCount` 方法，并通过 `setState` 方法更新计数器的值。在 `build` 方法中，我们使用 `_count` 的奇偶性来控制是否显示一个居中的文本控件，如果 `_count` 是偶数，则返回 `null`，否则返回一个 `Text` 控件，用于显示当前的计数器值。
>
> 这个例子中，当 `_count` 为偶数时，`build` 方法返回的 `body` 为 `null`，因此页面上没有任何内容，无法进行刷新。而当 `_count` 为奇数时，`build` 方法返回一个带有计数器值的 `Text` 控件，页面会刷新并显示该文本控件。
>
> 因此，如果要让页面正常刷新，请确保 `setState` 方法中的 `build` 方法始终返回一个有效的 `Widget`，而不是返回 `null`。
>
> 例外：
>
> ```
> void onClean() {
>   getSubTaskData().cleanSubTasks(widget.parentID).then((value) {
>     setState(() {});
>   });
> }
> 
> 
> 
> ```
>
> 在上述代码中，`setState()` 方法被调用，将包含 `getSubTaskData().cleanSubTasks(widget.parentID)` 的匿名函数添加到 State 对象的更新队列中。因此，当 `build()` 方法再次被调用时，将会使用最新的 State 对象来重建 Widget 树。
>
> 虽然 `setState()` 方法只在组件状态发生变化时才会触发 Widget 树的重建，但是它也可以在不改变状态的情况下触发重建。例如，如果 `build()` 方法返回的 Widget 树包含动态生成的组件，例如 `ListView` 或 `GridView`，那么当列表或网格中的元素发生变化时，`setState()` 方法可能会被调用来更新 Widget 树，即使组件的状态没有发生变化。在这种情况下，Flutter 框架将根据最新的 State 对象重建 Widget 树，并使用最新的数据更新动态生成的组件。
>
> 所以它会获取数据进行判断吗
>
> 
>
> 
>
> 不一定会获取数据进行判断。在 `setState()` 方法中，只有在将 State 对象更新到新状态时才会触发 Widget 树的重建。在这个例子中，`getSubTaskData().cleanSubTasks(widget.parentID)` 方法可能不会实际更新组件的状态，但是它会在组件的状态变化时被调用，从而将包含这个方法的闭包添加到 State 对象的更新队列中。当闭包被调用时，它可能会获取数据并执行某些操作，但这并不是必须的。最终，`setState()` 方法的唯一作用是告诉 Flutter 框架重新构建 Widget 树，并使用最新的 State 对象更新组件的状态和视图。
>
> 如果你将 `getSubTaskData().cleanSubTasks(widget.parentID)` 改为异步方法，并使用 `.then()` 方法来触发 `setState()`，则当异步方法完成时，Flutter 框架将根据最新的 State 对象重新构建 Widget 树，从而更新组件的状态和视图。
>
> 因此，你可以这样修改 `onClean()` 方法：
>
> ```
> scssCopy code
> void onClean() {
>   getSubTaskData().cleanSubTasks(widget.parentID).then((value) {
>     setState(() {});
>   });
> }
> ```
>
> 这将在 `getSubTaskData().cleanSubTasks(widget.parentID)` 完成后触发 `setState()`，从而更新组件的状态和视图。这也将确保在更新组件的状态之前，异步方法已经完成，从而避免了可能出现的状态不一致的问题。
>
> 但是setState的body是空的，这样会触发重新构建吗
>
> 
>
> 
>
> 即使 `setState()` 方法的主体为空，Flutter 框架仍然会根据最新的 State 对象重新构建 Widget 树，从而更新组件的状态和视图。这是因为 `setState()` 方法会通知框架，组件的状态已经发生了变化，框架需要重新构建 Widget 树，以便将新状态反映到视图中。
>
> 在你的示例中，即使 `setState()` 的主体为空，由于你在 `getSubTaskData().cleanSubTasks(widget.parentID)` 的 `then()` 方法中调用了 `setState()`，Flutter 框架仍然会根据最新的 State 对象重新构建 Widget 树，并使用最新的状态更新组件的状态和视图。
>
> 因此，使用空的 `setState()` 主体是一种常见的惯用方式，用于触发 Widget 树的重建，并使用最新的 State 对象更新组件的状态和视图。如果你只是想更新组件的状态，而不需要触发重建，则可以在 `setState()` 方法的主体中不执行任何操作。但是，如果你想触发 Widget 树的重建，就需要在 `setState()` 方法的主体中返回一个新的 Widget，或者将 Widget 树的一部分存储在 State 对象中，并更新它以反映最新的状态。















为什么要用super.dispose()，这不会导致super的dispose被调用两次吗

> 在使用 dispose 方法时，通常需要调用父类的 dispose 方法以确保其所持有的资源得到释放。在 Dart 和 Flutter 中，通常使用 `super.dispose()` 来调用父类的 dispose 方法。
>
> 调用 `super.dispose()` 不会导致父类的 dispose 方法被调用两次。实际上，当子类中的 dispose 方法被调用时，父类中的 dispose 方法会在子类的 dispose 方法中被隐式调用。这是因为在子类中调用 `super.dispose()` 时，实际上是在调用父类中的 dispose 方法。因此，只有一次 dispose 方法被调用。

dart中的const与static

> `const` 和 `static` 是 Dart 中两个重要的关键字，它们的作用不同。
>
> `const` 关键字用于声明编译时常量。它可以用于创建不可变的值，例如数字、字符串、布尔值等。与 `final` 不同的是，`const` 声明的变量的值在编译时就已经确定，并且在运行时不能更改。这意味着，对于同一常量，无论在多少个地方使用它，它们都是同一个实例。由于常量的值是在编译时确定的，因此常量的值在程序运行时是不会改变的。例如：
>
> ```
> const int x = 5;
> const String s = 'Hello';
> 
> ```
>
> `static` 关键字用于声明类变量或方法。与实例变量或方法不同，类变量或方法不需要创建类的实例就可以使用。这意味着，类变量或方法可以在类被实例化之前就被使用。静态方法只能访问静态变量，不能访问实例变量。例如：
>
> ```
> csharpCopy code
> class MyClass {
>   static int x = 5;
>   static void myMethod() {
>     // ...
>   }
> }
> ```
>
> 在上面的例子中，我们声明了一个名为 `MyClass` 的类，并定义了一个静态变量 `x` 和一个静态方法 `myMethod()`。我们可以通过 `MyClass.x` 来访问静态变量 `x`，通过 `MyClass.myMethod()` 来调用静态方法 `myMethod()`。
>
> 需要注意的是，常量可以是静态的，但静态变量不一定是常量。常量是在编译时就已经确定的值，而静态变量可以在运行时改变其值。此外，常量必须在声明时就进行初始化，而静态变量可以在声明时进行初始化，也可以在静态方法中进行初始化。



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

### 复用逻辑

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

### 在比较的过程中，会关心组件使用的资源吗，比如TextEditingController

在比较过程中，组件使用的资源是需要被关注的，因为资源的不合理使用可能会导致一些问题，比如内存泄漏等。在比较过程中，Flutter框架会比较组件树上的每一个节点，如果一个节点没有变化，那么它的子树也会被认为没有变化，从而避免了对子树进行不必要的重建。

对于`TextEditingController`等资源，通常应该在`dispose`方法中进行释放，以避免内存泄漏。因此，在比较过程中，如果一个组件在上一次构建时使用了一个资源，但在当前构建中没有使用该资源，那么就需要在`dispose`方法中进行资源的释放。否则，这个资源就会被保留下来，并可能导致内存泄漏问题。



## Null与null的区别

在Dart和Flutter中，`Null`和`null`是不同的概念。

`Null`是一个预定义的Dart类，表示一个空对象。它有一个唯一的实例，即`null`。

`null`是一个特殊的Dart对象，用于表示空值或缺少值。它是一个对象引用，可以分配给任何变量，即使变量的类型不是`Null`。

需要注意的是，`Null`和`null`在使用时的语法也略有不同。`Null`是一个类型名，用于声明变量的类型。例如：

```
dartCopy code
Null a; // 正确：声明变量a的类型为Null
```

而`null`则是一个字面量，用于表示空值。例如：

```
dartCopy code
String? str = null; // 声明一个可空的字符串变量，并将其赋值为null
```

总的来说，`Null`是一个类，用于表示空对象的类型，而`null`是一个对象引用，用于表示空值或缺少值。

## flutter中表示空的Widget

在Flutter中，可以使用`SizedBox.shrink()` 或 `Container()`来表示空的Widget。

1. 使用`SizedBox.shrink()`:

```
dartCopy code
SizedBox.shrink()
```

`SizedBox.shrink()`是一个零尺寸的小部件，它可以在布局中占用空间，但不会渲染任何内容。

1. 使用`Container()`:

```
dartCopy code
Container()
```

`Container()`是一个具有默认尺寸和没有子节点的小部件。它在布局中占用空间，但不会渲染任何内容。

这两种方法都可以用来表示空Widget，具体取决于上下文和使用情况。