---
date: 2024-07-11T19:43:00+08:00
title: "Rust中的log库们"
url: "/internet/rust/logs"
toc: true
draft: false
description: "Rust中的log库们"
slug: "log"
tags: ["log", "rust", "env_logger", "tracing"]
showDateUpdated: true
---

## log

添加依赖：

```shell
cargo add log
```

打印一下:

```rust
fn main() {
    log::info!("Hello, world!");
}
```

执行程序后发现没有任何输出。这是因为log只是一个日志的门面（A lightweight logging facade）:

```rust
/// A trait encapsulating the operations required of a logger.
pub trait Log: Sync + Send {
    /// Determines if a log message with the specified metadata would be
    /// logged.
    ///
    /// This is used by the `log_enabled!` macro to allow callers to avoid
    /// expensive computation of log message arguments if the message would be
    /// discarded anyway.
    ///
    /// # For implementors
    ///
    /// This method isn't called automatically by the `log!` macros.
    /// It's up to an implementation of the `Log` trait to call `enabled` in its own
    /// `log` method implementation to guarantee that filtering is applied.
    fn enabled(&self, metadata: &Metadata) -> bool;

    /// Logs the `Record`.
    ///
    /// # For implementors
    ///
    /// Note that `enabled` is *not* necessarily called before this method.
    /// Implementations of `log` should perform all necessary filtering
    /// internally.
    fn log(&self, record: &Record);

    /// Flushes any buffered records.
    ///
    /// # For implementors
    ///
    /// This method isn't called automatically by the `log!` macros.
    /// It can be called manually on shut-down to ensure any in-flight records are flushed.
    fn flush(&self);
}
```

如果没有选择具体的日志实现，它会使用`NopLogger`, 而`NopLogger`是不会输出任何日志的:

```rust
// Just used as a dummy initial value for LOGGER
struct NopLogger;

impl Log for NopLogger {
    fn enabled(&self, _: &Metadata) -> bool {
        false
    }

    fn log(&self, _: &Record) {}
    fn flush(&self) {}
}

impl<T> Log for &'_ T
where
    T: ?Sized + Log,
{
    fn enabled(&self, metadata: &Metadata) -> bool {
        (**self).enabled(metadata)
    }

    fn log(&self, record: &Record) {
        (**self).log(record);
    }
    fn flush(&self) {
        (**self).flush();
    }
}


// ......

// The LOGGER static holds a pointer to the global logger. It is protected by
// the STATE static which determines whether LOGGER has been initialized yet.
static mut LOGGER: &dyn Log = &NopLogger;
```

## simple_logger

就像名字暗示的那样，simple_logger就是一个简单的Log实现, 只能在控制台输出：

```rust
fn log(&self, record: &Record) {
            // ........
            let message = format!("{}{} [{}{}] {}", timestamp, level_string, target, thread, record.args());

            #[cfg(not(feature = "stderr"))]
            println!("{}", message);

            #[cfg(feature = "stderr")]
            eprintln!("{}", message);
        }
    }
```

使用举例:

```rust
fn main() {
    simple_logger::SimpleLogger::new().env().init().unwrap();

    log::info!("Hello, world!");
}
```

## env_logger

添加依赖：

```shell
cargo add log env_logger
```

`env_logger`是比`simple_logger`复杂些的Log实现。

从名字上看`env_logger`的愿景是通过环境变量来控制日志输出的行为，但这不是它的主要卖点（`simple_logger`也可以通过环境变量来设置日志级别）.
相比于`simple_logger`, `env_logger`:

1. 提供了更丰富的样式配置
2. 输出可选`stdout` 或者`stderr`, `simple_logger`只能选择`stdout`。
3. 可以按模块来配置日志。

`env_logger`的默认日志级别是`Error`:

```rust
use log::{error, info, warn};

fn main() {
    env_logger::init();

    let max_level = log::max_level();
    println!("Max log level: {:?}", max_level);

    info!("This is a info message");
    warn!("This is a warn message");
    error!("This is a error message");
}
```

输出：

```
Max log level: Error
[2024-07-11T04:45:34Z ERROR logs] This is a error message
```

通过环境变量来指定日志级别为info：

```shell
 RUST_LOG=info cargo run
Max log level: Info
[2024-07-11T05:01:19Z INFO  logs] This is a info message
[2024-07-11T05:01:19Z WARN  logs] This is a warn message
[2024-07-11T05:01:19Z ERROR logs] This is a error message

```

## tracing

`tracing`，就像它的名字一样，用于”追踪“，因此所提供的信息会更详细。

```rust
use tracing::info;
use tracing_subscriber;

fn main() {
    // install global collector configured based on RUST_LOG env var.
    tracing_subscriber::fmt::init();

    let number_of_yaks = 3;
    // this creates a new event, outside of any spans.
    info!(number_of_yaks, "preparing to shave yaks");
}

```

输出：

```shell
2024-07-11T07:03:32.160942Z  INFO logs: preparing to shave yaks number_of_yaks=3
```

可以看到，默认输出了时间、日志级别、日志内容、参数名称和值。

### span

span是链路追踪中的概念，指一条链路中的某个模块/节点，在这个模块/节点中的日志有相同的span_id。

在tracing中，span也是指一个模块/节点日志，这些日志共享某些信息:

```rust
use tracing::{info, warn};
use tracing_subscriber;

fn main() {
    // install global collector configured based on RUST_LOG env var.
    tracing_subscriber::fmt::init();

    hello(&User {
        name: "stong".to_owned(),
        age: 20,
    })
}

struct User {
    name: String,
    age: u8,
}

fn hello(user: &User) {
    let request_span = tracing::info_span!(
        "hello moudle.",
        user_name = %user.name,
        user_age = %user.age,
    );

    let _request_span_guard = request_span.enter();

    info!("hello!");
    warn!("world!");
}
```

输出：

```shell
2024-07-11T07:25:02.781108Z  INFO hello moudle.{user_name=stong user_age=20}: logs: hello!
2024-07-11T07:25:02.781124Z  WARN hello moudle.{user_name=stong user_age=20}: logs: world!
```

可以看到两行日志通过`span`共享了非常多的日志信息.

### json格式化

添加依赖:

```toml
[dependencies]
log = "0.4.22"
tracing = "0.1.40"
tracing-bunyan-formatter = "0.3"
[dependencies.tracing-subscriber]
version = "0.3.18"
features = ["registry", "env-filter"]
[dependencies.uuid]
version = "1.10.0"
features = ["v4"]
```

完善代码：

```rust
use tracing::subscriber::set_global_default;
use tracing::{info, warn};
use tracing_bunyan_formatter::{BunyanFormattingLayer, JsonStorageLayer};
use tracing_subscriber;
use tracing_subscriber::{layer::SubscriberExt, EnvFilter, Registry};
use uuid::Uuid;

fn main() {
    let env_filter = EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info"));
    let formatting_layer = BunyanFormattingLayer::new("logs blog".into(), std::io::stdout);
    let subscriber = Registry::default()
        .with(env_filter)
        .with(JsonStorageLayer)
        .with(formatting_layer);

    set_global_default(subscriber).expect("Failed to set subscriber");

    hello(&User {
        name: "stong".to_owned(),
        age: 20,
    })
}

struct User {
    name: String,
    age: u8,
}

fn hello(user: &User) {
    let request_id = Uuid::new_v4();
    let request_span = tracing::info_span!(
        "hello moudle.",
        %request_id,
        user_name = %user.name,
        user_age = %user.age,
    );

    let _request_span_guard = request_span.enter();

    info!("hello!");
    warn!("world!");
}

```

输出：

```json
{"v":0,"name":"logs blog","msg":"[HELLO MOUDLE. - START]","level":30,"hostname":"MacBook-Air.local","pid":12138,"ti
me":"2024-07-11T08:44:27.02071Z","target":"logs","line":31,"file":"src/main.rs","user_age":"20","user_name":"stong"
,"request_id":"20c7e1f7-f662-4b82-b6a6-237a7453dc62"}
{"v":0,"name":"logs blog","msg":"[HELLO MOUDLE. - EVENT] hello!","level":30,"hostname":"MacBook-Air.local","pid":12
138,"time":"2024-07-11T08:44:27.02088Z","target":"logs","line":40,"file":"src/main.rs","user_age":"20","user_name":
"stong","request_id":"20c7e1f7-f662-4b82-b6a6-237a7453dc62"}
{"v":0,"name":"logs blog","msg":"[HELLO MOUDLE. - EVENT] world!","level":40,"hostname":"MacBook-Air.local","pid":12
138,"time":"2024-07-11T08:44:27.020901Z","target":"logs","line":41,"file":"src/main.rs","user_age":"20","user_name"
:"stong","request_id":"20c7e1f7-f662-4b82-b6a6-237a7453dc62"}
{"v":0,"name":"logs blog","msg":"[HELLO MOUDLE. - END]","level":30,"hostname":"MacBook-Air.local","pid":12138,"time
":"2024-07-11T08:44:27.020923Z","target":"logs","line":31,"file":"src/main.rs","elapsed_milliseconds":0,"user_name"
:"stong","request_id":"20c7e1f7-f662-4b82-b6a6-237a7453dc62","user_age":"20"}
```

### bunyan

使用bunyan的好处之一就是可以通过命令来修改输出格式，执行命令：

```shell
cargo run | bunyan
```

输出内容更易读：

```shell
[2024-07-11T09:31:38.748554Z]  INFO: logs blog/2580 on MacBook-Air.local: [HELLO MOUDLE. - START] (target=logs, lin
e=31, file=src/main.rs, user_name=stong, user_age=20, request_id=6c8fb545-a9cf-4ca1-9f19-2fb2276190b9)
[2024-07-11T09:31:38.748611Z]  INFO: logs blog/2580 on MacBook-Air.local: [HELLO MOUDLE. - EVENT] hello! (target=lo
gs, line=40, file=src/main.rs, user_name=stong, user_age=20, request_id=6c8fb545-a9cf-4ca1-9f19-2fb2276190b9)
[2024-07-11T09:31:38.748636Z]  WARN: logs blog/2580 on MacBook-Air.local: [HELLO MOUDLE. - EVENT] world! (target=lo
gs, line=41, file=src/main.rs, user_name=stong, user_age=20, request_id=6c8fb545-a9cf-4ca1-9f19-2fb2276190b9)
[2024-07-11T09:31:38.74866Z]  INFO: logs blog/2580 on MacBook-Air.local: [HELLO MOUDLE. - END] (target=logs, line=3
1, file=src/main.rs, user_name=stong, elapsed_milliseconds=0, user_age=20, request_id=6c8fb545-a9cf-4ca1-9f19-2fb22
76190b9)

```

### 优化+actix_web

把日志初始化的代码抽象一下，再使用actix_web实现http api接口：

```rust
use actix_web::{web, App, HttpResponse, HttpServer, Responder};
use tracing::subscriber::set_global_default;
use tracing::{info, warn, Subscriber};
use tracing_bunyan_formatter::{BunyanFormattingLayer, JsonStorageLayer};
use tracing_subscriber::{layer::SubscriberExt, EnvFilter, Registry};
use uuid::Uuid;

fn get_subscriber(name: String, env_filter: String) -> impl Subscriber + Send + Sync {
    let env_filter =
        EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new(env_filter));
    let formatting_layer = BunyanFormattingLayer::new(name, std::io::stdout);
    Registry::default()
        .with(env_filter)
        .with(JsonStorageLayer)
        .with(formatting_layer)
}

fn init_subscribe(subscriber: impl Subscriber + Send + Sync) {
    set_global_default(subscriber).expect("Failed to set subscriber");
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    let subscriber = get_subscriber("logs blog".into(), "info".into());
    init_subscribe(subscriber);

    HttpServer::new(|| App::new().route("/hello/{name}/{age}", web::get().to(hello)))
        .bind("127.0.0.1:8080")?
        .run()
        .await
}

async fn hello(info: web::Path<(String, u8)>) -> impl Responder {
    let (name, age) = info.into_inner();
    let request_id = Uuid::new_v4();
    let request_span = tracing::info_span!(
        "hello moudle.",
        %request_id,
        user_name = %name,
        user_age = %age,
    );

    let _request_span_guard = request_span.enter();

    HttpResponse::Ok().body(format!("Hello, {}!", name))
}

```

访问接口:

```shell
curl localhost:8080/hello/stong/20
```

输出：

```shell
[2024-07-11T09:34:32.512943Z]  INFO: logs blog/7156 on MacBook-Air.local: [HELLO MOUDLE. - START] (target=logs, lin
e=36, file=src/main.rs, request_id=45d55d0a-6db9-4f0c-b198-1305e1ee3507, user_name=stong, user_age=20)
[2024-07-11T09:34:32.513061Z]  INFO: logs blog/7156 on MacBook-Air.local: [HELLO MOUDLE. - END] (target=logs, line=
36, file=src/main.rs, user_age=20, request_id=45d55d0a-6db9-4f0c-b198-1305e1ee3507, user_name=stong, elapsed_millis
econds=0)
```

### instrument：隔离日志和业务逻辑

上述代码将业务逻辑和日志混在一起，不利于维护，可以使用`instrument`来隔离:

```rust
#[tracing::instrument(
    name = "visit hello",
    skip(info),
    fields(
        user_name = %info.0,
        user_age = %info.1,
    )
)]
async fn hello(info: web::Path<(String, u8)>) -> impl Responder {
    let (name, _) = info.into_inner();

    HttpResponse::Ok().body(format!("Hello, {}!", name))
}

```

输出：

```shell
[2024-07-11T09:40:33.496575Z]  INFO: logs blog/17573 on MacBook-Air.local: [VISIT HELLO - START] (target=logs, line
=33, file=src/main.rs, user_name=stong, user_age=20)
[2024-07-11T09:40:33.496908Z]  INFO: logs blog/17573 on MacBook-Air.local: [VISIT HELLO - END] (target=logs, line=3
3, file=src/main.rs, elapsed_milliseconds=0, user_name=stong, user_age=20)
```

**代码更清晰，而功能未受影响**

### tracing_actix_web

web库一般都提供插件功能，我们可以通过tracing_actix_web来实现日志插件：

```rust
// ...
use tracing_actix_web::TracingLogger;

#[actix_web::main]
async fn main() -> std::io::Result<()> {
// ....
HttpServer::new(|| {
        App::new()
            .wrap(TracingLogger::default())
            .route("/hello/{name}/{age}", web::get().to(hello))
    })
    .bind("127.0.0.1:8080")?
    .run()
    .await
// ....
}
```

注销掉之前的`instrument`:

```rust
// #[tracing::instrument(
//     name = "visit hello",
//     skip(info),
//     fields(
//         user_name = %info.0,
//         user_age = %info.1,
//     )
// )]
async fn hello(info: web::Path<(String, u8)>) -> impl Responder {
    let (name, _) = info.into_inner();

    HttpResponse::Ok().body(format!("Hello, {}!", name))
}
```

输出：

```shell
[2024-07-11T10:15:01.527904Z]  INFO: logs blog/42318 on MacBook-Air.local: [HTTP REQUEST - START] (target=tracing_a
ctix_web::root_span_builder, line=41, http.scheme=http, otel.name="HTTP GET /hello/{name}/{age}", http.client_ip=12
7.0.0.1, http.target=/hello/stong/20, otel.kind=server, http.user_agent=curl/8.6.0, http.method=GET, http.flavor=1.
1, http.host=localhost:8080, request_id=18c2c4c9-bafe-43e2-8eb9-7f885ae37df5, http.route=/hello/{name}/{age})
    file: /Users/stong/.cargo/registry/src/mirrors.ustc.edu.cn-61ef6e0cd06fb9b8/tracing-actix-web-0.7.11/src/root_s
pan_builder.rs
[2024-07-11T10:15:01.528624Z]  INFO: logs blog/42318 on MacBook-Air.local: [HTTP REQUEST - END] (target=tracing_act
ix_web::root_span_builder, line=41, http.scheme=http, otel.name="HTTP GET /hello/{name}/{age}", elapsed_millisecond
s=0, http.client_ip=127.0.0.1, http.target=/hello/stong/20, otel.kind=server, http.user_agent=curl/8.6.0, http.meth
od=GET, http.flavor=1.1, http.host=localhost:8080, request_id=18c2c4c9-bafe-43e2-8eb9-7f885ae37df5, http.status_cod
e=200, otel.status_code=OK, http.route=/hello/{name}/{age})
    file: /Users/stong/.cargo/registry/src/mirrors.ustc.edu.cn-61ef6e0cd06fb9b8/tracing-actix-web-0.7.11/src/root_s
pan_builder.rs
```

输出内容太多，导致可读性很低，可以过滤掉一些不重要的信息：

```rust
    let skipped_fields = vec!["http.host", "http.flavor", "file"];
    let formatting_layer = BunyanFormattingLayer::new(name, std::io::stdout)
        .skip_fields(skipped_fields.into_iter())
        .expect("One of the specified fields cannot be skipped");

```

输出：

```shell
[2024-07-11T14:51:44.069846Z]  INFO: logs blog/81862 on MacBook-Air.lan: [VISIT HELLO - START] (target=logs
, line=40, user_age=20, user_name=stong)
[2024-07-11T14:51:44.070002Z]  INFO: logs blog/81862 on MacBook-Air.lan: [VISIT HELLO - END] (target=logs,
line=40, user_age=20, user_name=stong, elapsed_milliseconds=0)
```

### 日志文件

可以将日志输出到文件：

```rust
use tracing::subscriber::set_global_default;
use tracing_appender::non_blocking::{self, WorkerGuard};
use tracing_bunyan_formatter::{BunyanFormattingLayer, JsonStorageLayer};
use tracing_subscriber::{layer::SubscriberExt, EnvFilter, Registry};

pub fn init_subscriber(name: String, env_filter: String) -> WorkerGuard {
    let env_filter =
        EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new(env_filter));
    let skipped_fields = vec!["http.host", "http.flavor", "file"];

    let file_appender = tracing_appender::rolling::hourly("./logs", "log");
    let (file_writer, guard) = tracing_appender::non_blocking(file_appender);

    let formatting_layer_file = BunyanFormattingLayer::new(name, file_writer)
        .skip_fields(skipped_fields.into_iter())
        .expect("One of the specified fields cannot be skipped");
    let subscriber = Registry::default()
        .with(env_filter)
        .with(JsonStorageLayer)
        .with(formatting_layer_file);
    set_global_default(subscriber).expect("Failed to set subscriber");
    guard
}

```

注意`guard`要保活，否则日志将不会输出。
