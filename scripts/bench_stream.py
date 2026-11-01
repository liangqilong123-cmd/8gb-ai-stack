"""流式速度测量：任何 OpenAI 兼容端点通用（llama.cpp / llama-swap / vLLM / 各类引擎）

用法：
    # 测解码速度（tok/s）
    python bench_stream.py --base http://127.0.0.1:8091/v1 --model my-model --tokens 512

    # 测预填充速度（喂长文本，只等首 token）
    python bench_stream.py --base http://127.0.0.1:8091/v1 --model my-model \
        --prompt-file long.txt --prefill-only

输出：首 token 延迟、解码速度、总耗时、token 计数。
注意：不同口径（含/不含首 token 延迟）能差 30%，比较时务必同口径。
"""

import argparse
import json
import time
import urllib.request


def count_tokens_approx(text):
    """粗估 token 数：中文约 1.5 token/字，英文约 1 token/4 字符。"""
    han = sum(1 for c in text if "\u4e00" <= c <= "\u9fff")
    other = len(text) - han
    return int(han * 1.5 + other / 4)


def stream(base, model, prompt, max_tokens, prefill_only, temperature):
    url = base.rstrip("/") + "/chat/completions"
    body = {
        "model": model,
        "messages": [{"role": "user", "content": prompt}],
        "max_tokens": max_tokens,
        "temperature": temperature,
        "stream": True,
        "stream_options": {"include_usage": True},
    }
    req = urllib.request.Request(
        url, data=json.dumps(body).encode(), headers={"Content-Type": "application/json"}
    )

    t0 = time.time()
    first = None
    out_chars = 0
    usage = None

    with urllib.request.urlopen(req, timeout=1800) as resp:
        for raw in resp:
            line = raw.decode("utf-8", "ignore").strip()
            if not line.startswith("data:"):
                continue
            payload = line[5:].strip()
            if payload == "[DONE]":
                break
            try:
                obj = json.loads(payload)
            except json.JSONDecodeError:
                continue
            if obj.get("usage"):
                usage = obj["usage"]
            choices = obj.get("choices") or []
            if choices:
                delta = choices[0].get("delta") or {}
                piece = delta.get("content") or ""
                if piece:
                    if first is None:
                        first = time.time()
                        if prefill_only:
                            # 首 token 到手即可，继续读完以便准确统计
                            pass
                    out_chars += len(piece)

    t_end = time.time()
    return t0, first, t_end, out_chars, usage


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", default="http://127.0.0.1:8080/v1")
    ap.add_argument("--model", required=True)
    ap.add_argument("--prompt", default="用中文写一段关于秋天的散文，约三百字。")
    ap.add_argument("--prompt-file", help="从文件读 prompt（测预填充用）")
    ap.add_argument("--tokens", type=int, default=512, help="最大生成 token 数")
    ap.add_argument("--prefill-only", action="store_true", help="只关心首 token 延迟（预填充速度）")
    ap.add_argument("--temperature", type=float, default=0.0)
    args = ap.parse_args()

    prompt = args.prompt
    if args.prompt_file:
        prompt = open(args.prompt_file, encoding="utf-8").read()

    in_tok = count_tokens_approx(prompt)
    t0, first, t_end, out_chars, usage = stream(
        args.base, args.model, prompt, args.tokens, args.prefill_only, args.temperature
    )

    if first is None:
        print("❌ 未收到任何 token（检查模型名/服务状态）")
        return

    prompt_tok = (usage or {}).get("prompt_tokens", in_tok)
    completion_tok = (usage or {}).get("completion_tokens", count_tokens_approx("x" * 0))
    prefill = first - t0
    gen = t_end - first

    print("=" * 46)
    print(f"模型        : {args.model}")
    print(f"输入 token  : 约 {prompt_tok}")
    print(f"首 token    : {prefill:.2f} s")
    if prefill > 0:
        print(f"预填充速度  : {prompt_tok / prefill:.0f} tok/s")
    if not args.prefill_only and completion_tok:
        print(f"输出 token  : 约 {completion_tok}（{out_chars} 字符）")
        print(f"解码耗时    : {gen:.2f} s")
        if gen > 0 and completion_tok > 1:
            print(f"解码速度    : {(completion_tok - 1) / gen:.1f} tok/s")
    print(f"总耗时      : {t_end - t0:.2f} s")
    print("=" * 46)


if __name__ == "__main__":
    main()
