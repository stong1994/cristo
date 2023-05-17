+++

date = 2023-05-17T11:30:00+08:00
title = "CVP架构"
url = "/internet/ai/law-ai-cvp"

toc = true

+++



## 什么是CVP

CVP架构是在Zilliz 创始人在一次访谈中提出的一种**AI应用架构体系**。

- C就是Chatgpt这类大模型，负责向量运算

- V就是向量数据库（vector database），负责向量的存储

- P就是Prompt Engineering，负责向量的交互

## Supabase Clippy

### 简介

Supabase是一个开源的firebase替代方案，Clippy是其开发的一个搜索助手，能够回答开发者提出的Supabase相关的问题。

![](https://raw.githubusercontent.com/stong1994/images/master/picgo/202305171035146.png)

Clippy的目的是学习Supabase中的文档，当用户提出Supabase相关的问题时，通过“交流”的方式进行回答。

### 工作原理

#### 数据向量化

**我们需要理解用户输入的内容，“理解”的意思是说，我们需要在已知的内容中找到距离用户输入最近的内容。**

在这个过程中，我们需要**将内容和用户输入向量化**，然后通过向量运算来找到具体最近的内容。

![](https://supabase.com/_next/image?url=%2Fimages%2Fblog%2Fembeddings%2Fvector-similarity.png&w=1920&q=75)

[图片来源：Storing OpenAI embeddings in Postgres with pgvector (supabase.com)](https://supabase.com/blog/openai-embeddings-postgres-vector)

那么问题是，**如何将数据向量化？**

只有“理解”数据，才能对其向量化，这就用到了大语言模型，而openai也通过[接口](https://platform.openai.com/docs/api-reference/embeddings)开放了这一能力。

#### 向量存储

向量存储使用的是postgresql的插件[pgvector](https://github.com/pgvector/pgvector)，目前已经内置到Supabase中，开发者直接使用SDK或者http接口调用即可。

对向量存储感兴趣的也可以看下其他的向量数据库，比如Milvus。

#### Prompt

从[源码](https://github.com/supabase-community/nextjs-openai-doc-search/blob/main/pages/api/vector-search.ts)中可以看到Clippy的提示语是这样的：

```
You are a very enthusiastic Supabase representative who loves
to help people! Given the following sections from the Supabase
documentation, answer the question using only that information,
outputted in markdown format. If you are unsure and the answer
is not explicitly written in the documentation, say
"Sorry, I don't know how to help with that."
`}

Context sections:
${contextText}

Question: """
${sanitizedQuery}
"""

Answer as markdown (including related code snippets if available)
```

其中contextText是通过向量计算查找到的“距离最近”的内容，sanitizedQuery是用户输入。

对于提示语工程感兴趣的可以阅读《向Chatgpt提问的艺术》这本小册子。

#### 回答用户问题的完整流程

1. 判断用户输入是否违规。这个检查步骤Clippy也交给了[openai](https://platform.openai.com/docs/api-reference/moderations/create)
2. 将用户输入向量化。这个在**数据向量化**一节已经讲过
3. 向量计算，查询距离用户输入“最近”的内容
4. 将上一步骤获得的内容与用户的输入结合起来放到提示语中，通过[openai的接口](https://platform.openai.com/docs/api-reference/completions/create)来获得”人性化“的回答。

## CVP的场景

通过Supabase Clippy的例子可以看到实现这样的一个功能并不复杂，比如[lvwzhen/law-cn-ai: ⚖️ AI 法律助手 ](https://github.com/lvwzhen/law-cn-ai)直接将法律文件替换为Supabase的文档，并修改提示语和一些界面就实现了一个法律助手！

除此之外，CVP还可以应用于产品推荐、搜索、识别、知识问答等多种场景！



## 相关资料

1. [对话 Zilliz 星爵：大模型时代，需要新的「存储基建」](https://mp.weixin.qq.com/s/u9vQRiQSxQJww26JDuOGLQ)
1. [The Open Source Firebase Alternative | Supabase](https://supabase.com/)
1. [API Reference - OpenAI API](https://platform.openai.com/docs/api-reference/embeddings)
1. [Supabase Clippy: ChatGPT for Supabase Docs](https://supabase.com/blog/chatgpt-supabase-docs))
1. [supabase-community/nextjs-openai-doc-search: Template for building your own custom ChatGPT style doc search powered by Next.js, OpenAI, and Supabase](https://github.com/supabase-community/nextjs-openai-doc-search)