# 发布清单（发到 GitHub 前逐项打勾）

> 仓库已在本机初始化并提交（2 个 commit，13 个文件，189KB，无任何权重/密钥）。
> 路径：`D:\AI_Dev\8gb-ai-stack`

## 一、发布前必须替换的三处

- [ ] **LICENSE 里的 `<your-name>`** → 你的名字或 GitHub ID
- [ ] **README 里的 `<you>`**（git clone 地址示例）→ 你的 GitHub ID
- [ ] **configs 里的占位符**：`<LLAMA_DIR>`、`<MODELS_DIR>` —— 保留占位符是可以的（让别人改），
      但建议在 README 的「快速开始」确认已说明要替换

## 二、创建远端仓库（在浏览器里做，30 秒）

1. 打开 https://github.com/new
2. Repository name：`8gb-ai-stack`（或 `low-vram-llm-stack`）
3. **不要**勾选 "Add a README"（本地已有）
4. 可见性：Public
5. 创建

## 三、推送（在你自己的终端里执行）

```bash
cd /d/AI_Dev/8gb-ai-stack
git remote add origin https://github.com/<你的ID>/8gb-ai-stack.git
git branch -M main
git push -u origin main
```

**认证方式（二选一，都不需要把 token 发给我）**：

- **推荐**：先 `gh auth login`（GitHub CLI），浏览器授权一次，之后 push 免密
- 或用 Personal Access Token：push 时弹窗让你输入密码 → 粘贴 token 即可（token 由系统凭据管理器保存，不要写进任何文件）

## 四、发布后建议做的四件事（提升可信度）

1. **补一张实测截图**：`nvidia-smi` 显示 7.6GB 占用 + 一个对话窗口的截图，放 README 顶部
2. **加 Topics**：`local-llm` `low-vram` `llama-cpp` `windows` `quantization` `8gb-vram`
3. **写 Releases**：把你测过的配置打一个 `v0.1` tag
4. **Issue 模板**：两栏即可——「你的硬件 + 复现步骤」

## 五、绝对不要做的三件事

1. ❌ 不要 `git add` 任何 `.gguf` / `.safetensors` / `.ninfer`（.gitignore 已挡，但别用 `-f` 强加）
2. ❌ 不要提交 `.env`、`config.local.yaml`、任何含 key 的文件
3. ❌ 不要把别人的受限内容整段搬进来（如 NC 协议的讲稿、有限制条款的模型说明）

## 六、可选增强（第二轮迭代再做）

- [ ] `README.en.md`：英文版简介（能显著提高海外曝光）
- [ ] 把三个后端的切换写成 `scripts/switch-backend.ps1`（一条命令换引擎）
- [ ] 一个 `examples/` 目录：放实测用的 prompt 与输出样例
- [ ] CI：`python scripts/bench_stream.py --help` 跑一遍（证明脚本可执行）

## 七、发布文案（可直接当 README 首段或 HN/Reddit 帖首句）

> 8GB 显存的笔记本能跑 27B 模型吗？能——5.94GB 三元量化权重，256K 上下文，中文创作 28 tok/s，预填充 834 tok/s。
> 这个仓库是我把一台 RTX 4070 Laptop 压榨到极限的全部配置与实测数据：哪些模型装得下、上下文开到多长会崩塌、三个推理后端为什么必须互斥。
