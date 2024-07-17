---
date: 2024-07-14T01:43:00+08:00
title: "Rust中错误处理——libs"
url: "/internet/rust/error-libs"
toc: true
draft: false
description: "Rust中丰富的用于错误处理的仓库"
slug: "log"
tags: ["log", "rust", "错误处理", "thiserror", "anyhow"]
showDateUpdated: true
---

## thiserror

[thiserror](https://github.com/dtolnay/thiserror) 提供了更快捷的定义错误类型的能力。

在代码中，我们通常会为错误定义一些类型，这样上层在使用时可以根据错误类型进行不同的错误处理，比如：

```rust
pub enum DataStoreError {
    Disconnect(io::Error),
    Redaction(String),
    InvalidHeader { expected: String, found: String },
    Unknown,
}

```

使用并通过匹配错误类型进行处理：

```rust
pub fn insert_data<T>(data: T) -> Result<(), DataStoreError> {
    // .... 假设校验头部失败
    Err(DataStoreError::InvalidHeader {
        expected: "expected xxx".into(),
        found: "found ***".into(),
    })
}

fn handle_data<T>(data: T) {
    let result = insert_data(data);
    match result {
        Ok(_) => println!("Data inserted successfully"),
        Err(e) => match e {
            DataStoreError::InvalidHeader { expected, found } => {
                println!("Invalid header: expected {}, found {}", expected, found)
            }
            DataStoreError::Disconnect(e) => println!("Data store disconnected: {}", e),
            DataStoreError::Redaction(s) => println!("Data for key `{}` is not available", s),
            DataStoreError::Unknown => println!("Unknown data store error"),
        },
    }
}
```

通过模式匹配错误，并根据不同的类型打印不同的信息。 我们得到了想要的效果，但是考虑下：如果有多个使用方，每个使用方都需要自己定义错误信息的打印吗？让我们把这个功能通过实现`Error trait`来实现下：

```rust
impl Display for DataStoreError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            DataStoreError::Disconnect(e) => write!(f, "Data store disconnected: {}", e),
            DataStoreError::Redaction(s) => write!(f, "Data for key `{}` is not available", s),
            DataStoreError::InvalidHeader { expected, found } => {
                write!(f, "Invalid header (expected {}, found {})", expected, found)
            }
            DataStoreError::Unknown => write!(f, "Unknown data store error"),
        }
    }
}
impl std::fmt::Debug for DataStoreError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        error_chain_fmt(self, f)
    }
}
impl std::error::Error for DataStoreError {
    fn source(&self) -> Option<&(dyn std::error::Error + 'static)> {
        match self {
            // &str does not implement `Error` - we consider it the root cause
            Self::InvalidHeader { .. } => None,
            Self::Redaction(_) => None,
            Self::Disconnect(e) => Some(e),
            Self::Unknown => None,
        }
    }
}

fn error_chain_fmt(
    e: &impl std::error::Error,
    f: &mut std::fmt::Formatter<'_>,
) -> std::fmt::Result {
    writeln!(f, "{}\n", e)?;
    let mut current = e.source();
    while let Some(cause) = current {
        writeln!(f, "Caused by:\n\t{}", cause)?;
        current = cause.source();
    }
    Ok(())
}
```

封装后，我们直接打印错误就可以了：

```rust
fn handle_data<T>(data: T) {
    let result = insert_data(data);
    match result {
        Ok(_) => println!("Data inserted successfully"),
        Err(e) => println!("Error inserting data: {}", e),
    }
}
```

通过`thiserror`来简化上述那一套代码：

```rust
use thiserror::Error;

#[derive(Error, Debug)]
pub enum DataStoreError {
    #[error("data store disconnected")]
    Disconnect(#[from] io::Error),
    #[error("the data for key `{0}` is not available")]
    Redaction(String),
    #[error("invalid header (expected {expected:?}, found {found:?})")]
    InvalidHeader { expected: String, found: String },
    #[error("unknown data store error")]
    Unknown,
}
```

Pretty good!!!

`thiserror`语法：

```rust
#[error("{var}")] ⟶ write!("{}", self.var)
#[error("{0}")] ⟶ write!("{}", self.0)
#[error("{var:?}")] ⟶ write!("{:?}", self.var)
#[error("{0:?}")] ⟶ write!("{:?}", self.0)
```

## displaydoc

[displaydoc](https://github.com/yaahc/displaydoc)几乎和`thiserror`一模一样，除了他们定义错误的方式：
`thiserror`是通过`#[error("...")]`来定义错误信息，而`displaydoc`是通过文档注释`/// `来定义错误信息。

```rust
// ========== thiserror ==============
use thiserror::Error;

#[derive(Error, Debug)]
pub enum DataStoreError {
    #[error("data store disconnected")]
    Disconnect(#[from] io::Error),
    #[error("the data for key `{0}` is not available")]
    Redaction(String),
    #[error("invalid header (expected {expected:?}, found {found:?})")]
    InvalidHeader { expected: String, found: String },
    #[error("unknown data store error")]
    Unknown,
}

// ========== displaydoc ==============
use displaydoc::Display;
use thiserror::Error;

#[derive(Display, Error, Debug)]
pub enum DataStoreError {
    /// data store disconnected
    Disconnect(#[source] io::Error),
    /// the data for key `{0}` is not available
    Redaction(String),
    /// invalid header (expected {expected:?}, found {found:?})
    InvalidHeader { expected: String, found: String },
    /// unknown data store error
    Unknown,
}
```

通过`displaydoc`来定义错误信息，可以更好的和文档结合，方便阅读。

## snafu

[snafu](https://github.com/shepmaster/snafu)是一个比`thiserror`更复杂一些的日志库，相比于`thiserror`, `snafu`提供了"关联上下文并映射为具体错误类型"的能力：

```rust
use snafu::prelude::*;
use std::{fs, io, path::PathBuf};

#[derive(Debug, Snafu)]
enum Error {
    #[snafu(display("Unable to read configuration from {}", path.display()))]
    ReadConfiguration { source: io::Error, path: PathBuf },

    #[snafu(display("Unable to write result to {}", path.display()))]
    WriteResult { source: io::Error, path: PathBuf },
}

type Result<T, E = Error> = std::result::Result<T, E>;

fn process_data() -> Result<()> {
    let path = "config.toml";
    let configuration = fs::read_to_string(path).context(ReadConfigurationSnafu { path })?; // 关联上下文并映射为具体错误类型
    let path = unpack_config(&configuration);
    fs::write(&path, b"My complex calculation").context(WriteResultSnafu { path })?;
    Ok(())
}

fn unpack_config(data: &str) -> &str {
    "/some/path/that/does/not/exist"
}

fn main() {
    match process_data() {
        Ok(_) => println!("Success!"),
        Err(e) => println!("Error: {:?}", e),
    }
}
// 输出:
// Error: ReadConfiguration { source: Os { code: 2, kind: NotFound, message: "No such file or directory" }, path: "config.toml" }
```

这有点像`thiserror`和`anyhow`的结合体。

## anyhow

[anyhow](https://github.com/dtolnay/anyhow)的作用是提供一个通用的`Error trait`来方便错误传递。
比如说`handle_data`函数需要返回一个标准的`Error trait`来批量内部细节，我们可以这样做：

```rust
fn handle_data<T>(data: T) -> Result<(), Box<dyn std::error::Error>> {
    let result = insert_data(data);
    match result {
        Ok(_) => Ok(()),
        Err(e) => Err(Box::new(e)),
    }
}
```

由于`std::error::Error`是一个`对象trait`, 无法在编译时确定具体类型，因此需要通过`Box`和`dyn`来进行"装盒".

上述代码可以通过`anyhow`来简化：

```rust
fn handle_data<T>(data: T) -> anyhow::Result<()> {
    insert_data(data)?;
    Ok(())
}
```

如果需要添加上下文，可以使用`context`方法:

```rust
fn handle_data<T>(data: T) -> anyhow::Result<()> {
    insert_data(data).context("Failed to insert data")
}
```

> 从上面的例子也可以看到, `anyhow`和`thiserror`虽然是处理错误的不同库，但是适用于不同的场景，因此可以搭配使用。

`anyhow`另一个常用的宏是`bail!`, 用于简化新建`anyhow::Error`:

```rust
bail!("Missing attribute: {}", missing);
// 等同于
return Err(anyhow!("Missing attribute: {}", missing));
```

`anyhow`兼容所有实现了`std::error::Error`的错误类型，因此使用`anyhow`可以很方便的传递错误信息。

## eyre簇

`eyre`有一系列库：

- [eyre](https://github.com/eyre-rs/eyre): `eyre`的核心库, 其定位与`anyhow`的相同，都是提供一个统一的`Error trait`, 但是`eyre`提供了更强大的定制能力。
- [color-eyre](https://github.com/eyre-rs/eyre/tree/master/color-eyre): 提供更丰富的输出样式

### eyre-通过`EyreHandler`自定义错误处理

`EyreHandler`是一个`trait`, 定义如下：

```rust
pub trait EyreHandler: Any + Send + Sync {
    // Required method
    fn debug(
        &self,
        error: &(dyn StdError + 'static),
        f: &mut Formatter<'_>
    ) -> Result;

    // Provided methods
    fn display(
        &self,
        error: &(dyn StdError + 'static),
        f: &mut Formatter<'_>
    ) -> Result { ... }
    fn track_caller(&mut self, location: &'static Location<'static>) { ... }
}
```

通过实现`EyreHandler`，可以自定义错误处理逻辑, 如：

```rust
use backtrace::Backtrace;
use eyre::EyreHandler;
use std::error::Error;
use std::{fmt, iter};

struct Handler {
    // custom configured backtrace capture
    backtrace: Option<Backtrace>,
    // customizable message payload associated with reports
    custom_msg: Option<&'static str>,
}

impl EyreHandler for Handler {
    fn debug(&self, error: &(dyn Error + 'static), f: &mut fmt::Formatter<'_>) -> fmt::Result {
        if f.alternate() {
            return fmt::Debug::fmt(error, f);
        }

        let errors = iter::successors(Some(error), |error| (*error).source());

        for (ind, error) in errors.enumerate() {
            write!(f, "\n{:>4}: {}", ind, error)?;
        }

        if let Some(backtrace) = self.backtrace.as_ref() {
            writeln!(f, "\n\nBacktrace:\n{:?}", backtrace)?;
        }

        if let Some(msg) = self.custom_msg.as_ref() {
            writeln!(f, "\n\n{}", msg)?;
        }

        Ok(())
    }
}
```

通过重写`debug`方法，可以自定义错误输出格式：

1. `Handler`包含一个自定义的错误信息`custom_msg`和错误的追踪信息`backtrace`.
2. 通过`source`将“错误链”提取出来，并依次打印其错误信息.
3. 然后打印错误追踪信息`backtrace`
4. 最后打印`Handler`的自定义错误信息

写好`Handler`之后，如何使用呢？这时候就需要使用`Hook`了，定义如下：

```rust
struct Hook {
    capture_backtrace: bool,
}

impl Hook {
    fn make_handler(&self, _error: &(dyn Error + 'static)) -> Handler {
        let backtrace = if self.capture_backtrace {
            Some(Backtrace::new())
        } else {
            None
        };

        Handler {
            backtrace,
            custom_msg: None,
        }
    }
}

// define a handler that captures backtraces unless told not to
fn install() -> Result<(), impl Error> {
    let capture_backtrace = std::env::var("RUST_BACKWARDS_TRACE")
        .map(|val| val != "0")
        .unwrap_or(true);

    let hook = Hook { capture_backtrace };

    eyre::set_hook(Box::new(move |e| Box::new(hook.make_handler(e))))
}
```

最后看下自定义错误格式的效果：

```rust
fn main() -> eyre::Result<()> {
    // Install our custom eyre report hook for constructing our custom Handlers
    install().unwrap();

    // construct a report with, hopefully, our custom handler!
    let mut report = eyre::eyre!("hello from custom error town!");

    // manually set the custom msg for this report after it has been constructed
    if let Some(handler) = report.handler_mut().downcast_mut::<Handler>() {
        handler.custom_msg = Some("you're the best users, you know that right???");
    }

    // print that shit!!
    Err(report)
}
```

运行程序，输出为：

```shell
Error:
   0: hello from custom error town!

Backtrace:
   0: backtrace::backtrace::libunwind::trace
             at /Users/stong/.cargo/registry/src/mirrors.ustc.edu.cn-61ef6e0cd06fb9b8/backtrace-0.3.73/src/
backtrace/libunwind.rs:116:5
      backtrace::backtrace::trace_unsynchronized
             at /Users/stong/.cargo/registry/src/mirrors.ustc.edu.cn-61ef6e0cd06fb9b8/backtrace-0.3.73/src/
backtrace/mod.rs:66:5
   1: backtrace::backtrace::trace
             at /Users/stong/.cargo/registry/src/mirrors.ustc.edu.cn-61ef6e0cd06fb9b8/backtrace-0.3.73/src/
backtrace/mod.rs:53:14
   2: backtrace::capture::Backtrace::create
             at /Users/stong/.cargo/registry/src/mirrors.ustc.edu.cn-61ef6e0cd06fb9b8/backtrace-0.3.73/src/
capture.rs:197:9
   3: backtrace::capture::Backtrace::new
             at /Users/stong/.cargo/registry/src/mirrors.ustc.edu.cn-61ef6e0cd06fb9b8/backtrace-0.3.73/src/
capture.rs:162:22
   4: errors::Hook::make_handler
             at /Users/stong/Project/Personal/rust_practise/errors/src/main.rs:40:18
   5: errors::install::{{closure}}
             at /Users/stong/Project/Personal/rust_practise/errors/src/main.rs:30:47
   6: eyre::capture_handler
             at /Users/stong/.cargo/registry/src/mirrors.ustc.edu.cn-61ef6e0cd06fb9b8/eyre-0.6.12/src/lib.r
s:601:23
   7: eyre::error::<impl eyre::Report>::from_adhoc
             at /Users/stong/.cargo/registry/src/mirrors.ustc.edu.cn-61ef6e0cd06fb9b8/eyre-0.6.12/src/error
.rs:114:28
   8: eyre::error::<impl eyre::Report>::msg
             at /Users/stong/.cargo/registry/src/mirrors.ustc.edu.cn-61ef6e0cd06fb9b8/eyre-0.6.12/src/error
.rs:70:9
   9: eyre::private::format_err
             at /Users/stong/.cargo/registry/src/mirrors.ustc.edu.cn-61ef6e0cd06fb9b8/eyre-0.6.12/src/lib.r
s:1316:13
  10: errors::main
             at /Users/stong/Project/Personal/rust_practise/errors/src/main.rs:11:22
  11: core::ops::function::FnOnce::call_once
             at /rustc/c6727fc9b5c64cefa7263486497ee95e529bd0f8/library/core/src/ops/function.rs:250:5
  12: std::sys::backtrace::__rust_begin_short_backtrace
             at /rustc/c6727fc9b5c64cefa7263486497ee95e529bd0f8/library/std/src/sys/backtrace.rs:155:18
  13: std::rt::lang_start::{{closure}}
             at /rustc/c6727fc9b5c64cefa7263486497ee95e529bd0f8/library/std/src/rt.rs:159:18
  14: core::ops::function::impls::<impl core::ops::function::FnOnce<A> for &F>::call_once
             at /rustc/c6727fc9b5c64cefa7263486497ee95e529bd0f8/library/core/src/ops/function.rs:284:13
      std::panicking::try::do_call
             at /rustc/c6727fc9b5c64cefa7263486497ee95e529bd0f8/library/std/src/panicking.rs:553:40
      std::panicking::try
             at /rustc/c6727fc9b5c64cefa7263486497ee95e529bd0f8/library/std/src/panicking.rs:517:19
      std::panic::catch_unwind
             at /rustc/c6727fc9b5c64cefa7263486497ee95e529bd0f8/library/std/src/panic.rs:350:14
      std::rt::lang_start_internal::{{closure}}
             at /rustc/c6727fc9b5c64cefa7263486497ee95e529bd0f8/library/std/src/rt.rs:141:48
      std::panicking::try::do_call
             at /rustc/c6727fc9b5c64cefa7263486497ee95e529bd0f8/library/std/src/panicking.rs:553:40
      std::panicking::try
             at /rustc/c6727fc9b5c64cefa7263486497ee95e529bd0f8/library/std/src/panicking.rs:517:19
      std::panic::catch_unwind
             at /rustc/c6727fc9b5c64cefa7263486497ee95e529bd0f8/library/std/src/panic.rs:350:14
      std::rt::lang_start_internal
             at /rustc/c6727fc9b5c64cefa7263486497ee95e529bd0f8/library/std/src/rt.rs:141:20
  15: std::rt::lang_start
             at /rustc/c6727fc9b5c64cefa7263486497ee95e529bd0f8/library/std/src/rt.rs:158:17
  16: _main



you're the best users, you know that right???
```

输出效果符合预期！

### color-eyre增强输出

编写一个执行`git`命令的程序：

```rust
use eyre::Context;
use std::process::Command;

fn main() {
    let output = Command::new("git")
        .arg("run")
        .output()
        .wrap_err("Failed to execute git command")
        .unwrap();
    println!("{:?}", String::from_utf8_lossy(&output.stderr));
}
```

输出为：

```shell
"git: 'run' is not a git command. See 'git --help'.\n\nThe most similar command is\n\tprune\n"
```

用`color-eyre`增强输出效果：

```rust
use color_eyre::{
    eyre::Report,
    eyre::{eyre, WrapErr},
    Section, SectionExt,
};
use std::process::Command;
use tracing::instrument;

trait Output {
    fn output2(&mut self) -> Result<String, Report>;
}

impl Output for Command {
    #[instrument]
    fn output2(&mut self) -> Result<String, Report> {
        let output = self.output()?;

        let stdout = String::from_utf8_lossy(&output.stdout);

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            Err(eyre!("cmd exited with non-zero status code"))
                .with_section(move || stdout.trim().to_string().header("Stdout:"))
                .with_section(move || stderr.trim().to_string().header("Stderr:"))
        } else {
            Ok(stdout.into())
        }
    }
}

```

通过为`Command`实现自定义的`Output trait`，我们为`Command`“新增”了`output2`方法。在`output2`中，如果命令执行失败，会：

- 通过`eyre!`宏返回一个`Report`错误
- 通过`with_section`方法添加`stdout`和`stderr`的输出信息

让我们模拟一个读取文件的操作来测试输出效果：

```rust
#[instrument]
fn main() -> Result<(), Report> {
    color_eyre::install()?;

    read_config().map(drop)
}

#[instrument]
fn read_file(path: &str) -> Result<String, Report> {
    Command::new("cat").arg(path).output2()
}

#[instrument]
fn read_config() -> Result<String, Report> {
    read_file("fake_file")
        .wrap_err("Unable to read config")
        .suggestion("try using a file that exists next time")
}
```

我们读取了一个不存在的文件，并通过`wrap_err`来包裹一层错误信息,并通过`suggestion`方法提供了一个建议。运行程序，输出为：
![](https://raw.githubusercontent.com/stong1994/images/master/picgo/202407171054407.png)

输出内容是带有颜色的！内容组要包含：

1. 错误链：在`Error`模块下输出了两条我们定义的错误信息
2. 定位: 在`Location`模块下输出了错误发生的位置
3. 标准输出：在`Stdout`模块下输出了命令结果的标准输出信息(命令执行失败，因此这个模块没有输出)
4. 标准错误：在`Stderr`模块下输出了标准错误信息
5. 错误追踪：在`SPANTRACE`模块下输出了错误追踪信息


## 推荐阅读
1. [Zero to Production in Rust：第8章-Error Handling]()
2. [RustConf 2020 - Error handling Isn't All About Errors by Jane Lusby](https://www.youtube.com/watch?v=rAF8mLI0naQ)
