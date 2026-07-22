已加好一套可直接用的 Docker 配置：

| 文件 | 作用 |
| --- | --- |
| `Dockerfile` | 多阶段构建：编译 Next.js + 安装 Python 依赖，同容器跑 API/Web |
| `docker/entrypoint.sh` | 同时启动 uvicorn（8000）和 Next（3000） |
| `.dockerignore` | 缩小构建上下文 |

**构建 / 运行：**

```bash
# CPU（默认 DEVICE=cpu）
docker build -t youdub-webui .
docker run --rm -p 3000:3000 --env-file .env \
  -v "$PWD/workfolder:/app/workfolder" \
  -v "$PWD/data:/app/data" \
  youdub-webui

# NVIDIA GPU
docker build --build-arg WITH_CUDA=1 -t youdub-webui:cuda .
docker run --gpus all --rm -p 3000:3000 --env-file .env -e DEVICE=cuda \
  -v "$PWD/workfolder:/app/workfolder" \
  -v "$PWD/data:/app/data" \
  youdub-webui:cuda
```

访问 `http://localhost:3000`。`.env` 里必须有 `YOUDUB_AUTH_PASSWORD_HASH`（生成方式见 README）。

镜像会很大（Whisper / Demucs / VoxCPM 等），首次构建和拉取模型都需要时间和磁盘空间。国内 PyPI 慢的话可以加：`--build-arg PIP_INDEX_URL=https://mirrors.aliyun.com/pypi/simple/`。