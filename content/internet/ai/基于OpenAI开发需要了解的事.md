+++

date = 2023-09-11T11:30:00+08:00
title = "基于OpenAI开发需要了解的事"
url = "/internet/ai/dev-with-openai-should-know"

toc = true

+++



## 引用上下文

ChatGPT最引人瞩目的一点就是它能够关联聊天内容的上下文，但是这并不是ChatGPT自动关联的，而是要在调用接口时把上下文传入进去。

因此，在众多的模型中都会规定一次请求的最长的上下文长度。比如`gpt-4-32k`模型支持的上下文最长为32K token。

注意：token数量并不是字符数量。

## token计算

调用ChatGPT接口后，会自动返回所花费的token数量，比如：

```json
{
  "id": "cmpl-uqkvlQyYK7bGYrRHQ0eXlWi7",
  "object": "text_completion",
  "created": 1589478378,
  "model": "gpt-3.5-turbo-instruct",
  "choices": [
    {
      "text": "\n\nThis is indeed a test",
      "index": 0,
      "logprobs": null,
      "finish_reason": "length"
    }
  ],
  "usage": {
    "prompt_tokens": 5,
    "completion_tokens": 7,
    "total_tokens": 12
  }
}
```

在这个响应中注明了花费了：

- 5个用于提示的token
- 7个用于完成对话的token
- 一共12个token

注意：在流式响应中是不会返回花费的token数量的，流式响应的结构是：

```json
{
  "id": "cmpl-7iA7iJjj8V2zOkCGvWF2hAkDWBQZe",
  "object": "text_completion",
  "created": 1690759702,
  "choices": [
    {
      "text": "This",
      "index": 0,
      "logprobs": null,
      "finish_reason": null
    }
  ],
  "model": "gpt-3.5-turbo-instruct"
}
```

因此token数量需要自己计算，计算规则可以参考openai开源的算法[tiktoken](github.com/openai/tiktoken)

平均来看，一个token相当约3/4个字符

## 三种角色

在调用ChatGPT的接口时，可以引用上下文，格式如下：

```json
{
  model="gpt-4",
  messages=[
        {"role": "system", "content": "Respond as a pirate."},
        {"role": "user", "content": "What is another name for tacking in sailing?"},
        {"role": "assistant", "content": "Rrrr, coming about be another way to say it."},
        {"role": "user", "content": "How do you do it?"}
    ]
}
```

可以看到，ChatGPT支持三种角色：system、assistant、user。

- System：用来引导ChatGPT的回答，比如设定角色、规划回复格式等等
- Assistant：ChatGPT生成的的回答
- User：用户的输入

## 参数控制

除了大语言模型model、承载上下文的messages，openai提供的接口还支持其他参数。

### max_tokens

这个参数是用来控制ChatGPT预测的token数量，而不是实际的响应内容中的token数量。

比如`max_tokens=10`会告诉ChatGPT在预测生成了10个token之后停止预测。

如果想要实现对响应内容的长度控制，可以考虑在system角色中设置，比如content内容为：请将回复内容长度限制在10个字符内。

### temperature

生成内容的灵活程度，值越高，生成的内容就越有”创意“，值越低，生成的内容就越”稳定“。范围为0~2，默认为1.

### n

生成的可选的内容数量。默认为1

### stream

是否使用流式传输进行相应。

### function_call

能够提供自动调用本地接口的能力。可以阅读[官方文档](https://platform.openai.com/docs/guides/gpt/function-calling)



## 相关资料

1. [How to make the chatGPT API do your bidding (programmingelectronics.com)](https://www.programmingelectronics.com/chatgpt-api/#:~:text=chatGPT Roles,-The role tells&text=assistant – Lets the model know,on the actual model responses.)