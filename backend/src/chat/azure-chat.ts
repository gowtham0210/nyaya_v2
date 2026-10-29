import type { AppConfig } from '../core/config.js';

export interface ChatTurn {
  role: 'user' | 'assistant';
  content: string;
}

export type ModelReply =
  | { kind: 'answer'; text: string }
  /** Azure's content filter blocked the question or the answer. */
  | { kind: 'filtered' }
  | { kind: 'failed'; reason: string };

const TIMEOUT_MS = 60_000;

/** One chat completion from an Azure OpenAI deployment (the v1 API). */
export async function azureChat(
  azure: NonNullable<AppConfig['azureOpenAi']>,
  system: string,
  turns: ChatTurn[],
): Promise<ModelReply> {
  let res: Response;
  try {
    res = await fetch(`${azure.endpoint}/openai/v1/chat/completions`, {
      method: 'POST',
      headers: { 'content-type': 'application/json', 'api-key': azure.apiKey },
      body: JSON.stringify({
        model: azure.chatDeployment,
        messages: [{ role: 'system', content: system }, ...turns],
        // Includes the model's reasoning; answers themselves are short.
        max_completion_tokens: 4000,
      }),
      signal: AbortSignal.timeout(TIMEOUT_MS),
    });
  } catch (e) {
    return { kind: 'failed', reason: (e as Error).name };
  }

  const body = (await res.json().catch(() => null)) as {
    error?: { code?: string };
    choices?: { finish_reason?: string; message?: { content?: string } }[];
  } | null;
  if (!res.ok) {
    if (body?.error?.code === 'content_filter') return { kind: 'filtered' };
    return { kind: 'failed', reason: `HTTP ${res.status}` };
  }
  const choice = body?.choices?.[0];
  if (choice?.finish_reason === 'content_filter') return { kind: 'filtered' };
  const text = choice?.message?.content?.trim();
  if (!text)
    return { kind: 'failed', reason: `empty (${choice?.finish_reason})` };
  return { kind: 'answer', text };
}
