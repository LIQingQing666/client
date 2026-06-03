/**
 * 智能客服核心逻辑
 * 基于 LangChain 框架思想，结合商品文档进行 RAG 问答
 *
 * 注意：由于 LangChain v1.x 核心包不包含 ChatOpenAI 实现，
 * 这里直接使用 fetch 调用 OpenAI 兼容 API，后续可无缝切换到 LangChain 完整版
 */
import { getVectorStore } from './vector_store.js';
import { getAllProductDocs } from './product_docs.js';

/** LLM 配置（从环境变量读取） */
function getLLMConfig() {
  const apiUrl = process.env.LLM_API_URL;
  const apiKey = process.env.LLM_API_KEY;

  if (!apiUrl || !apiKey) {
    throw new Error(
      '[LangChain CS] LLM_API_URL 和 LLM_API_KEY 必须在 .env 文件中配置',
    );
  }

  return { apiUrl, apiKey };
}

/** 对话消息类型 */
export interface ChatMessage {
  role: 'user' | 'assistant' | 'system';
  content: string;
}

/**
 * 构建系统提示词
 * 将商品文档作为知识库上下文注入
 */
function buildSystemPrompt(docsContent: string): string {
  return `你是一个电商售后智能助手"小抖"，由抖音电商平台提供，热情友好、耐心细致。

【核心职责】
- 回答用户关于商品的咨询（规格、价格、功能、使用方法等）
- 解答售后问题（退换货政策、退款流程等）
- 根据用户的提问，从知识库中检索相关信息并总结回答

【知识库】
${docsContent}

【回答要求】
1. 只基于上面提供的知识库回答，不要编造不存在的信息
2. 如果知识库中找不到相关信息，请说"抱歉，这个问题我需要转接人工客服帮您处理"，不要尝试编造答案
3. 回答要简洁明了，控制在100字以内
4. 语气要亲切友好，适当使用emoji表情
5. 涉及价格时注明当前售价
6. 对于退货退款问题，告知用户可以在订单详情页申请，退款以抖币形式返还

【禁止行为】
- 不要编造商品参数或政策
- 不要询问用户的个人隐私信息
- 不要进行价格谈判或私自承诺优惠`;
}

/**
 * 调用 LLM API（OpenAI 兼容格式）
 * 直接使用 fetch 调用，保持轻量
 *
 * 支持的平台：
 * - OpenAI / Azure OpenAI
 * - 智谱AI (ChatGLM) - bigmodel.cn
 * - 通义千问 (阿里云)
 * - DeepSeek
 * - 任何 OpenAI 兼容的 API
 */
async function callLLM(messages: ChatMessage[]): Promise<string> {
  const { apiUrl, apiKey } = getLLMConfig();

  // 修正 URL：智谱 AI 的 API 基础地址不含 /chat/completions
  let fullUrl = apiUrl.trim();
  // 移除末尾的 /
  if (fullUrl.endsWith('/')) {
    fullUrl = fullUrl.slice(0, -1);
  }
  // 如果不是以 /chat/completions 结尾，则拼接
  if (!fullUrl.endsWith('/chat/completions')) {
    fullUrl += '/chat/completions';
  }

  // 模型名称：可从环境变量配置，默认 gpt-3.5-turbo
  const model = process.env.LLM_MODEL || 'glm-4-plus';

  const body = {
    model: model,
    messages: messages.map((m) => ({
      role: m.role,
      content: m.content,
    })),
    temperature: 0.7,
    max_tokens: 500,
  };

  console.log(`[LangChain CS] 请求 LLM: ${fullUrl}, model: ${model}`);

  const response = await fetch(fullUrl, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${apiKey}`,
    },
    body: JSON.stringify(body),
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(
      `LLM API 请求失败: ${response.status} ${response.statusText}\n${errorText}`,
    );
  }

  const data = (await response.json()) as {
    choices?: Array<{ message?: { content?: string } }>;
  };

  const content = data?.choices?.[0]?.message?.content;
  if (!content) {
    throw new Error('LLM API 返回格式异常，缺少 choices[0].message.content');
  }

  return content.trim();
}

/**
 * 智能客服问答
 * @param userMessage 用户当前输入
 * @param history 历史对话记录（最多保留最近6条）
 * @returns AI 回复内容
 */
export async function askAI(
  userMessage: string,
  history?: ChatMessage[],
): Promise<string> {
  try {
    // 1. 从向量存储检索相关商品文档
    const vectorStore = getVectorStore();
    const relevantDocs = await vectorStore.search(userMessage, 3);

    // 2. 拼接所有文档内容
    const docsContent = relevantDocs
      .map((doc) => `【${doc.name}】\n${doc.content}`)
      .join('\n\n---\n\n');

    // 3. 构建系统提示词
    const systemPrompt = buildSystemPrompt(docsContent);

    // 4. 构建完整消息列表
    const messages: ChatMessage[] = [
      { role: 'system', content: systemPrompt },
    ];

    // 添加历史消息（取最近6条，避免超长）
    if (history && history.length > 0) {
      const recentHistory = history.slice(-6);
      messages.push(...recentHistory);
    }

    // 添加当前用户问题
    messages.push({ role: 'user', content: userMessage });

    // 5. 调用 LLM
    const reply = await callLLM(messages);
    return reply;
  } catch (error) {
    console.error('[LangChain CS] AI 调用失败:', error);
    // 降级处理：如果 LLM 调用失败，返回兜底回复
    return '抱歉，我正在努力理解您的问题，请稍后再试，或点击"转人工"联系人工客服。🙏';
  }
}

/**
 * 获取欢迎语
 * 首次进入客服时调用
 */
export function getWelcomeMessage(): string {
  const productNames = getAllProductDocs()
    .map((doc) => doc.name)
    .join('、');

  return `你好呀！我是智能助手"小抖"🤖，很高兴为您服务！\n\n我目前可以为您解答商品的相关问题，包括商品详情、使用说明、退换货政策等。\n\n请告诉我您想了解什么，我会尽力帮助您～如果问题比较复杂，我也可以帮您转接人工客服哦！`;
}
