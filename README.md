# 8GB 显存本地大模型实战栈

> **一台 RTX 4070 Laptop（8GB 显存）+ 24GB 内存的 Windows 笔记本，跑 27B 三元量化模型，256K 上下文，中文创作 28 tok/s。**
> 本仓库不是教程合集，是一份**实测过的配置与数据**：哪些模型装得下、上下文能开多长、速度掉在哪一步、三个推理后端如何互斥。

## 为什么有这个仓库

8GB 显存在本地 AI 圈里是「地狱难度」：想跑大模型就要 4-bit 量化 + 部分层卸载，想开长上下文就会遇到 KV 缓存爆炸，装了图片模型（ComfyUI）又会被吃掉 1.9GB。

网上大量 8GB 配置贴要么只贴参数不讲数据，要么贴的是 16GB 卡的参数。本仓库的每条结论都附实测数字与测量方法，你可以自己复现。

## 硬件基线

| 项目 | 配置 |
|---|---|
| GPU | NVIDIA RTX 4070 Laptop，**8GB 显存** |
| 内存 | 24GB DDR（实测可用约 20GB） |
| 系统 | Windows 11 |
| 磁盘 | 模型放机械/固态数据盘，系统盘只放程序 |

> 8GB 卡的关键不是「能装多大」，而是「同一时刻只能装一个」。详见 [显存互斥](docs/显存互斥与上下文预算.md)。

## 实测数据（同一台机器，同一天，同口径）

### 27B 三元量化模型（PTQ1，权重 5.94GB）

| 场景 | 速度 |
|---|---|
| 中文长文创作 | **28 tok/s** |
| 高度重复性文本 | **82 tok/s**（MTP 接受率 96%） |
| 贪心解码 | 38 tok/s |
| 预填充（1.37 万字） | **834 tok/s** |
| 预填充（23.2 万 token 灌入） | 418 tok/s |
| 上下文 | 262,144（实测三针检索 3/3 命中） |

### 上下文长度与预填充速度的关系（关键曲线）

| 上下文设置 | 预填充速度 | 结论 |
|---|---|---|
| 80K | 2,370 tok/s（llama.cpp 全显存） | **安全上限** |
| 96K | 开始劣化 | 可用但吃力 |
| 128K | **63 tok/s**（掉 40 倍） | 崩塌：KV 塞不进显存，预填充要在显存/内存间来回搬 |
| 192K | 13.6 tok/s | 不可用 |

**这条曲线的成因**：KV 缓存 `q4_0` 为 18 KiB/token，`f16` 为 64 KiB/token——8GB 卡开长上下文，**必须**用 4-bit KV。

### 视觉塔的两种跑法

| 方案 | 显存开销 | 效果 |
|---|---|---|
| `--vision`（GPU） | 需额外 1.4GB 运行时预留，8GB 卡装不下 | 失败：`requested Engine runtime reservation requires ... but only ... available` |
| `--vision-cpu` | **0** | 每张图编码多几秒，功能完整可用 |

## 快速开始

```bash
# 1. 克隆
git clone https://github.com/<you>/8gb-ai-stack.git && cd 8gb-ai-stack

# 2. 改路径：把 configs/ 里所有 <LLAMA_DIR> / <MODELS_DIR> 换成你自己的
grep -rn "<LLAMA_DIR>\|<MODELS_DIR>" configs/

# 3. 起服务（二选一）
#    A. llama-swap（多模型路由，自动卸载/加载）
llama-swap.exe -config configs/llama-swap.config.yaml -watch-config
#    B. NInfer（单模型高上下文，含视觉）
powershell -ExecutionPolicy Bypass -File configs/ninfer-start.ps1

# 4. 验证
curl http://127.0.0.1:8080/v1/models
```

模型去哪里下、多大、什么许可，见 [MODELS.md](MODELS.md)。**本仓库不含任何权重文件。**

## 目录

| 路径 | 内容 |
|---|---|
| `configs/llama-swap.config.yaml` | 多模型路由配置（9 个模型档位，含显存与上下文注释） |
| `configs/ninfer-start.ps1` | 27B 单模型启动脚本（256K 上下文 + CPU 视觉 + MTP） |
| `configs/start-ninfer.bat` | 纯 ASCII 双击启动器（防重复启动） |
| `docs/显存互斥与上下文预算.md` | **三后端互斥规则** + 上下文上限实测 + KV 缓存算账 |
| `docs/实测数据.md` | 全部速度数据的测量方法与口径 |
| `docs/故障排查.md` | OOM、掉速、上下文崩塌、进程被回收、驱动 TDR |
| `scripts/bench_stream.py` | 任意 OpenAI 兼容端点的流式速度测量 |
| `scripts/vram_watch.ps1` | 显存看门狗（低于阈值报警，专治「模型不报错但掉速」） |

## 已知限制（先说清楚，省得你踩坑）

1. **同一时刻只能跑一个后端**：llama-swap / 长上下文引擎 / NInfer 互斥，切换有十几秒加载等待
2. **ComfyUI 常驻会吃掉约 1.9GB**：出图时别同时跑大模型，否则速度从 30 掉到 5-10 tok/s
3. **≥4.8GB 的模型必须独占显存**；只有两个小模型能共存（1.8B 翻译 + 0.6B 向量）
4. **本仓库数据来自单台笔记本**：不同型号的显存带宽、散热、功耗墙都会影响速度，请把这里的数字当**量级参考**而非基准
5. 三元量化（PTQ1）在 8GB 卡上是「质量换空间」的极限操作，长文质量会下降；能接受再用

## 许可

代码 MIT；文档 CC BY-NC-SA 4.0（可转载，勿商用）。模型权重各自的许可见 [MODELS.md](MODELS.md)——本仓库不分发权重。
