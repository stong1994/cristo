---
title: "不花一分钱搭建一个博客"
date: 2021-01-31T16:30:51+08:00
url: "/life/build_free_blog"
isCJKLanguage: true
keywords:
  - hugo
  - blog
tags:
  - life
authors:
  - cristo
toc: true
draft: false
---



[相关文章](https://mp.weixin.qq.com/s/pW7iHOQLwMDkFU_bgXeTuA)

[hugo的官方文档](https://gohugo.io/about/)

## 安装hugo

### 1. 使用安装包

[下载地址](https://github.com/gohugoio/hugo/releases)

### 2. 源码安装

> 提前准备好go环境

执行命令：`go get -v github.com/gohugoio/hugo`

#### 踩坑

有些主题需要使用`extended version`，比如[hugo-coder](https://themes.gohugo.io/hugo-coder/)，如果使用了这类主题，在启动hugo时会报错

> ```
> ERROR 2020/xx/xx TOCSS: failed to transform "style.coder-dark.css" (text/x-scss): resource "scss/scss/coder-dark.scss_9e20ccd2d8034c8e0fd83b11fb6e2bd5" not found in file cache
> Built in 75 ms
> Error: Error building site: TOCSS: failed to transform "style.coder.css" (text/x-scss): resource "scss/scss/coder.scss_fd4b5b3f9a48bc0c7f005d2f7a4cc30f" 
> not found in file cache
> ```

因此在使用这类主题时需要使用hugo的extended版本，安装步骤如下：

```
git clone https://github.com/gohugoio/hugo.git
cd hugo
go install --tags extended
```

[文档地址](https://gohugo.io/getting-started/installing/)

#### 校验是否安装成功

`hugo version`

看到版本信息即为成功。

## 创建博客

### 1.初始化博客

`hugo new site cristo`

### 2.选择主题

[主题地址](https://themes.gohugo.io/)

我选的是[hugo-coder](https://themes.gohugo.io/hugo-coder/)，因为看上去很简洁。

### 3.使用主题

挑选好主题后，在主题页面中都会有example展示和使用步骤，以`hugo-coder`为例：

1. 关联主题仓库

   ```
   cd cristo
   git submodule add https://github.com/luizdepra/hugo-coder.git themes/hugo-coder
   ```

2. 修改配置文件

   配置文件为项目下的`config.toml`文件

   可以先使用`cristo/themes/hugo-coder/exampleSite/config.toml`，然后再做定制化配置

3. 启动hugo

   在项目路径下执行命令`hugo server`

   输出内容：

   ```
   Start building sites …
   
                      | EN | PT-BR
   -------------------+----+--------
     Pages            | 11 |    11
     Paginator pages  |  0 |     0
     Non-page files   |  0 |     0
     Static files     |  5 |     5
     Processed images |  0 |     0
     Aliases          |  5 |     4
     Sitemaps         |  2 |     1
     Cleaned          |  0 |     0
   
   Built in 242 ms
   Watching for changes in /xxx/cristo/{archetypes,content,data,layouts,static,themes}
   Watching for config changes in /xxx/cristo/config.toml
   Environment: "development"
   Serving pages from memory
   Running in Fast Render Mode. For full rebuilds on change: hugo server --disableFastRender
   Web Server is available at http://localhost:1313/ (bind address 127.0.0.1)
   Press Ctrl+C to stop
   ```

   按照提示打开浏览器，输入地址：`http://localhost:1313/`，即可看到一个简单的博客。

   ![](https:/raw.githubusercontent.com/stong1994/images/master/picgo/20210124160116.png)

## 修改配置

1. 修改头像图片

   报错`Refused to load the image 'LOREM_IPSUM_URL' because it violates the following Content Security Policy directive: "img-src 'self' data:".`

   网上的资料是将`img-src 'self'`替换为`img-src * 'self' data: https:`

   但是我全局替换后仍未正常显式，后边的解决办法为在`static`目录下创建`images`目录，然后将图片拷贝过来，然后在配置文件中将头像地址设置为`images/xxx.jpg`即可

### 填充博客

此时点击Blog会显示404.

在 content/posts 目录下新增一个文件：`_index.md`，内容如下：

```
---
title: "文章列表"
---
```

再次点击Blog标签，会显示上述信息。

#### 增加关于页面

同样的，在 content/posts 目录下新增文件 `about.md`，正文内容随意，类似这样：

```
---
title: "关于"
date: "2020-12-01"
---

这是关于页面。
```

#### 增加博客

新博客文件名为test-post.md，执行命令：`hugo new posts/test-post.md`

posts目录下会新增test-post.md，内容如下

```
+++
draft = true
date = 2021-01-24T23:36:51+08:00
title = ""
description = ""
slug = ""
authors = []
tags = []
categories = []
externalLink = ""
series = []
+++
```

其中加号间的内容为元数据，在 Hugo 中叫做 Front Matter。

- 加号表示toml格式
- 减号表示yaml格式
- 大括号表示json格式

`isCJKLanguage: true`: 用于准确计算中文字数



## GitHub page

在github下的创建仓库：**账号名**.github.io

进入仓库，在setting中找到Github Pages，

## hugo 基本命令

### hugo new site quickstart

创建一个名为`quickstart`的站点

### hugo new posts/my-first-post.md

创建一个文件名为`my-first-post.md`的博客。

### hugo server 

启动hugo服务器

### hugo -d docs

构建静态页面并将其放到`docs`目录下，如果不加`-d docs`，则默认目录为`public`

## 禁止发布某些博客的方法

Hugo allows you to set `draft`, `publishdate`, and even `expirydate` in your content’s [front matter](https://gohugo.io/content-management/front-matter/). By default, Hugo will not publish:

1. Content with a future `publishdate` value
2. Content with `draft: true` status
3. Content with a past `expirydate` value



## hugo 基本目录

```
.
├── archetypes
├── config.toml
├── content
├── data
├── layouts
├── static
└── themes
```

### [`archetypes`](https://gohugo.io/content-management/archetypes/)

使用`hugo new`命令来创建内容文件，这些文件至少会包含`date`, `title`以及`draft = true`

### [`assets`](https://gohugo.io/hugo-pipes/introduction/#asset-directory)

存储所有需要在 [Hugo Pipes](https://gohugo.io/hugo-pipes/)中处理的文件，只有那些使用了`.Permalink` 或者 `.RelPermalink`的文件会被放到`public`目录下

### [`config`](https://gohugo.io/getting-started/configuration/)

存储配置指令，这些指令存储在格式为JSON、YAML或者TOML的文件中。一个最简单的配置是在项目根路径下配置`config.toml`

### [`content`](https://gohugo.io/content-management/organization/)

网站中的所有内容会放到这个目录下，目录下的每个直接子目录都是 [content section](https://gohugo.io/content-management/sections/)，如果你的博客有三个板块：`blog`, `articles`, and `tutorials`，那么在目录下会有三个子目录`content/blog`, `content/articles`和`content/tutorials`

### [`data`](https://gohugo.io/templates/data-templates/)

存储在hugo生成网站时的配置文件，比如创建一些动态内容的[数据模板](https://gohugo.io/templates/data-templates/) 

### [`layouts`](https://gohugo.io/templates/)

存储html格式的模板文件，这些文件用来将内容渲染成静态页面，模板包括 [list pages](https://gohugo.io/templates/list/),  [homepage](https://gohugo.io/templates/homepage/), [taxonomy templates](https://gohugo.io/templates/taxonomy-templates/), [partials](https://gohugo.io/templates/partials/), [single page templates](https://gohugo.io/templates/single-page-templates/)等等。

### [`static`](https://gohugo.io/content-management/static-files/)

存储所有的静态内容：images、css、JavaScript等

### **resources**

*不是默认生成的*

缓存一些文件来加速生成，也能被一些模板作者用来分发SASS文件

## 基本配置

### **baseURL**

域名的根路径

### **hasCJKLanguage** 

如果是true，自动检测中文/日文/韩文内容，使得 `.Summary` 和 `.WordCount` 表现正确

### imaging

```
[imaging]
# Default resample filter used for resizing. Default is Box,
# a simple and fast averaging filter appropriate for downscaling.
# See https://github.com/disintegration/imaging
resampleFilter = "box"

# Default JPEG quality setting. Default is 75.
quality = 75

# Anchor used when cropping pictures.
# Default is "smart" which does Smart Cropping, using https://github.com/muesli/smartcrop
# Smart Cropping is content aware and tries to find the best crop for each image.
# Valid values are Smart, Center, TopLeft, Top, TopRight, Left, Right, BottomLeft, Bottom, BottomRight
anchor = "smart"

# Default background color.
# Hugo will preserve transparency for target formats that supports it,
# but will fall back to this color for JPEG.
# Expects a standard HEX color string with 3 or 6 digits.
# See https://www.google.com/search?q=color+picker
bgColor = "#ffffff"

[imaging.exif]
 # Regexp matching the fields you want to Exclude from the (massive) set of Exif info
# available. As we cache this info to disk, this is for performance and
# disk space reasons more than anything.
# If you want it all, put ".*" in this config setting.
# Note that if neither this or ExcludeFields is set, Hugo will return a small
# default set.
includeFields = ""

# Regexp matching the Exif fields you want to exclude. This may be easier to use
# than IncludeFields above, depending on what you want.
excludeFields = ""

# Hugo extracts the "photo taken" date/time into .Date by default.
# Set this to true to turn it off.
disableDate = false

# Hugo extracts the "photo taken where" (GPS latitude and longitude) into
# .Long and .Lat. Set this to true to turn it off.
disableLatLong = false
```

### markup

装饰Markdown，有多种装饰器，目前默认的装饰器为Goldmark

```
markup:
  asciidocExt:
    attributes: {}
    backend: html5
    extensions: []
    failureLevel: fatal
    noHeaderOrFooter: true
    preserveTOC: false
    safeMode: unsafe
    sectionNumbers: false
    trace: false
    verbose: false
    workingFolderCurrent: false
  blackFriday:
    angledQuotes: false
    extensions: null
    extensionsMask: null
    footnoteAnchorPrefix: ""
    footnoteReturnLinkContents: ""
    fractions: true
    hrefTargetBlank: false
    latexDashes: true
    nofollowLinks: false
    noreferrerLinks: false
    plainIDAnchors: true
    skipHTML: false
    smartDashes: true
    smartypants: true
    smartypantsQuotesNBSP: false
    taskLists: true
  defaultMarkdownHandler: goldmark
  goldmark:
    extensions:
      definitionList: true
      footnote: true
      linkify: true
      strikethrough: true
      table: true
      taskList: true
      typographer: true
    parser:
      attribute: true
      autoHeadingID: true
      autoHeadingIDType: github
    renderer:
      hardWraps: false
      unsafe: false
      xhtml: false
  highlight:
    anchorLineNos: false
    codeFences: true
    guessSyntax: false
    hl_Lines: ""
    lineAnchors: ""
    lineNoStart: 1
    lineNos: false
    lineNumbersInTable: true
    noClasses: true
    style: monokai
    tabWidth: 4
  tableOfContents:
    endLevel: 3
    ordered: false
    startLevel: 2
```

- unsafe: Goldmark默认情况下是不会渲染原生HTML和安全性未知的链接，如果需要内联很多HTML或者JavaScript，需要将其设置为true

### [menu](https://gohugo.io/content-management/menus/)

hugo允许通过内容的`front matter`来增加内容到菜单，也可以通过配置文件

```
[menu]

  [[menu.main]]
    identifier = "about"
    name = "about hugo"
    pre = "<i class='fa fa-heart'></i>"
    url = "/about/"
    weight = -110

  [[menu.main]]
    name = "getting started"
    post = "<span class='alert'>New!</span>"
    pre = "<i class='fa fa-road'></i>"
    url = "/getting-started/"
    weight = -100
```

- url: 相对于`baseURL`的路径

### **[paginate](https://gohugo.io/templates/pagination/)** 

默认的分页数量

### **[taxonomies](https://gohugo.io/content-management/taxonomies#configure-taxonomies)**

内容间逻辑关系的分类

```
[taxonomies]
  category = "categories"
  categories_weight = 44
  tag = "tags"
  tags_weight = 22
```

每个内容都会产生category和tag，并且按照权重来渲染顺序。

如果某些内容需要自定义的元数据，则创建文件`/content/<TAXONOMY>/<TERM>/_index.md`

YAML格式：

```
---
title: "Bruce Willis"
wikipedia: "https://en.wikipedia.org/wiki/Bruce_Willis"
---
```

TOML格式：

```
+++
aliases = [
    "/posts/my-original-url/",
    "/2010/01/01/even-earlier-url.html"
]
+++
```



### **theme** 

主题

### **themesDir** 

hugo读取主题的文件目录

### **timeout** 

生成内容的超时时间，默认10秒

### **watch**



## frontmatter

*以yaml格式为准*

### 分类

两种分类方式：`categories`与`tags`(暂时不清楚两者的区别)

通过在`frontmatter`中标记标签，可以对文章进行分组，这样可以通过路径**host**/tags或者**host**/categories就可以看到所有分组的博客。

如果不喜欢路径中存在复数，可以在`config.toml`中指定为单数

```
[taxonomies]
  category = "category"
  tag = "tag"
```

这样在`frontmatter`中也需要使用单数:

```
tag: 
  -- post
```

查看分组的路径更改为：**host**/tag

## 目录项TOC

根据markdown的目录设置博客目录

1. 找到`themes/{theme}/layouts/_default/single.html` ，在`{{ define "content" }}下`添加

   ```
   <div id="toc" class="well col-md-4 col-sm-6">
   {{ .TableOfContents }}
   </div>
   ```

2. 在markdown博客中，设置`toc=true`