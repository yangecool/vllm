#!/bin/bash
# ---------------------------------------------------------------------------
# build_gfx1201_full.sh — build the gfx1201 vLLM image.
#
# What it does:  starts from a pre-built base image (Dockerfile.rocm_base),
#   compiles AITER (gfx1201) + vLLM from local source, and produces the
#   final runtime image.
#
# Usage:
#   # Default (auto-detects tag from git):
#   bash docker/build_gfx1201_full.sh
#
#   # Override everything via env:
#   BASE_IMAGE=my-registry/vllm-rocm:latest \
#   IMAGE_TAG=my-registry/vllm-openai-rocm:my-tag \
#   AITER_ROCM_ARCH="gfx1201" \
#   PYTORCH_ROCM_ARCH="gfx1201" \
#       bash docker/build_gfx1201_full.sh
# ---------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
VLLM_DIR="${WORKSPACE_ROOT}/vllm"

# ---- build args (overridable via env) ------------------------------------
BASE_IMAGE="${BASE_IMAGE:-vllm/vllm-openai-rocm:v0.25.0-base}"
AITER_ROCM_ARCH="${AITER_ROCM_ARCH:-gfx1201}"
PYTORCH_ROCM_ARCH="${PYTORCH_ROCM_ARCH:-gfx1201}"
MAX_JOBS="${MAX_JOBS:-$(nproc)}"
HTTP_PROXY="${HTTP_PROXY:-http://127.0.0.1:10808/}"
HTTPS_PROXY="${HTTPS_PROXY:-http://127.0.0.1:10808/}"

# ---- auto-detect tag from git --------------------------------------------
BUILT_TAG=""
if [ -z "${BUILD_VARIANT:-}" ]; then
    if BUILT_TAG=$(git -C "${VLLM_DIR}" describe --tags --abbrev=0 2>/dev/null); then
        BUILD_VARIANT="${BUILT_TAG%_v*}"
    else
        BUILD_VARIANT="hvat-gfx1201-scratch"
    fi
fi

if [ -z "${VLLM_BASE_VERSION:-}" ]; then
    if [ -n "${BUILT_TAG}" ]; then
        VLLM_BASE_VERSION="${BUILT_TAG##*_v}"
    else
        VLLM_BASE_VERSION="0.25.0"
    fi
fi

# ---- image tag -----------------------------------------------------------
# Auto-generated from BUILD_VARIANT + VLLM_BASE_VERSION.
# Override via env: IMAGE_TAG=my-registry/vllm:my-tag
REGISTRY="${REGISTRY:-ccr.ccs.tencentyun.com/rcomlibrary}"
IMAGE_REPO="${IMAGE_REPO:-vllm-openai-rocm}"
IMAGE_TAG="${IMAGE_TAG:-${REGISTRY}/${IMAGE_REPO}:${BUILD_VARIANT}_v${VLLM_BASE_VERSION}}"

FULL_VERSION="${VLLM_BASE_VERSION}+${BUILD_VARIANT}"

echo "============================================"
echo "[build] BASE_IMAGE         = ${BASE_IMAGE}"
echo "[build] AITER_ROCM_ARCH    = ${AITER_ROCM_ARCH}"
echo "[build] PYTORCH_ROCM_ARCH  = ${PYTORCH_ROCM_ARCH}"
echo "[build] VLLM_BASE_VERSION  = ${VLLM_BASE_VERSION}"
echo "[build] BUILD_VARIANT      = ${BUILD_VARIANT}"
echo "[build] wheel version      = ${FULL_VERSION}"
echo "[build] IMAGE_TAG          = ${IMAGE_TAG}"
echo "[build] MAX_JOBS           = ${MAX_JOBS}"
echo "============================================"

# ---- docker build --------------------------------------------------------
DOCKER_BUILDKIT=1 docker build \
    --network=host \
    -f "${SCRIPT_DIR}/Dockerfile.gfx1201_full" \
    -t "${IMAGE_TAG}" \
    --build-arg BASE_IMAGE="${BASE_IMAGE}" \
    --build-arg PYTORCH_ROCM_ARCH="${PYTORCH_ROCM_ARCH}" \
    --build-arg AITER_ROCM_ARCH="${AITER_ROCM_ARCH}" \
    --build-arg HTTP_PROXY="${HTTP_PROXY}" \
    --build-arg HTTPS_PROXY="${HTTPS_PROXY}" \
    --build-arg max_jobs="${MAX_JOBS}" \
    --build-arg VLLM_BASE_VERSION="${VLLM_BASE_VERSION}" \
    --build-arg BUILD_VARIANT="${BUILD_VARIANT}" \
    --progress=plain \
    "${WORKSPACE_ROOT}"

echo "[build] done — image: ${IMAGE_TAG}"
