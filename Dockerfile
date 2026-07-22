# YouDub WebUI — API (FastAPI) + Web (Next.js) in one image.
#
# CPU (default):
#   docker build -t youdub-webui .
#
# NVIDIA GPU (needs NVIDIA Container Toolkit on the host):
#   docker build --build-arg WITH_CUDA=1 -t youdub-webui:cuda .
#   docker run --gpus all -p 3000:3000 --env-file .env -e DEVICE=cuda \
#     -v "$PWD/workfolder:/app/workfolder" -v "$PWD/data:/app/data" youdub-webui:cuda
#
# Required: YOUDUB_AUTH_PASSWORD_HASH in env (see README).
# Open http://localhost:3000 (Next proxies /api to the in-container backend).

ARG NODE_VERSION=22
ARG PYTHON_VERSION=3.12

FROM node:${NODE_VERSION}-bookworm-slim AS web-builder
WORKDIR /src/apps/web
COPY apps/web/package.json apps/web/package-lock.json ./
RUN npm ci --ignore-scripts --no-audit --no-fund
COPY apps/web/ ./
ENV NEXT_TELEMETRY_DISABLED=1 \
    NEXT_SERVER_API_BASE_URL=http://127.0.0.1:8000
RUN npm run build
FROM python:${PYTHON_VERSION}-bookworm AS runtime

ARG WITH_CUDA=0
ARG PIP_INDEX_URL=https://pypi.org/simple
ARG NODE_VERSION=22

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    NEXT_TELEMETRY_DISABLED=1 \
    NEXT_SERVER_API_BASE_URL=http://127.0.0.1:8000 \
    WORKFOLDER=/app/workfolder \
    MODEL_CACHE_DIR=/app/data/modelscope \
    DEVICE=cpu \
    YOUDUB_AUTH_COOKIE_SECURE=false \
    YOUDUB_AUTH_COOKIE_SAMESITE=strict

COPY --from=node:${NODE_VERSION}-bookworm-slim /usr/local /usr/local

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      bash \
      ffmpeg \
      fonts-noto-cjk \
      libsndfile1 \
      sox \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt requirements-pytorch-cu128.txt ./
RUN python -m pip install -U pip \
 && if [ "$WITH_CUDA" = "1" ]; then \
      python -m pip install -r requirements-pytorch-cu128.txt; \
    fi \
 && python -m pip install -i "${PIP_INDEX_URL}" -r requirements.txt \
 && if [ "$WITH_CUDA" = "1" ]; then \
      python -m pip install --force-reinstall --no-deps -r requirements-pytorch-cu128.txt; \
    fi

COPY backend ./backend
COPY submodule ./submodule
COPY scripts ./scripts
COPY --from=web-builder /src/apps/web/.next ./apps/web/.next
COPY --from=web-builder /src/apps/web/public ./apps/web/public
COPY --from=web-builder /src/apps/web/package.json ./apps/web/package.json
COPY --from=web-builder /src/apps/web/node_modules ./apps/web/node_modules
COPY --from=web-builder /src/apps/web/next.config.ts ./apps/web/next.config.ts

COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh \
 && mkdir -p /app/workfolder /app/data/modelscope

EXPOSE 3000 8000
VOLUME ["/app/workfolder", "/app/data"]

ENTRYPOINT ["/entrypoint.sh"]
