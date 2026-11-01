# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Cognitio S.r.l.
#
# The quickstart agent: a small LangGraph application on the official Python
# slim image.
#
# The Python image is pinned by the digest of its multi-platform index, and
# every package is installed from requirements.txt, where each version is
# pinned and each distribution's hash is recorded, as prebuilt wheels only, so
# no package is compiled during the build. SOURCE_DATE_EPOCH, when the build
# sets it, makes the compiled bytecode depend on the sources rather than on
# the time of the build.
FROM python:3.13-slim@sha256:2d44738ebf4ce5f63b9d9ea871e9c7cfdc0426f7b0c97cac915fd88ded1d86bb AS build
ARG SOURCE_DATE_EPOCH
COPY requirements.txt /tmp/requirements.txt
RUN python -m venv /opt/agent \
 && /opt/agent/bin/pip install --no-cache-dir --disable-pip-version-check --require-hashes --only-binary=:all: \
      -r /tmp/requirements.txt

FROM python:3.13-slim@sha256:2d44738ebf4ce5f63b9d9ea871e9c7cfdc0426f7b0c97cac915fd88ded1d86bb
LABEL org.opencontainers.image.title="quickstart-agent" \
      org.opencontainers.image.description="A small LangGraph agent answering through an OpenAI-compatible endpoint and keeping its conversations in Valkey." \
      org.opencontainers.image.licenses="Apache-2.0" \
      org.opencontainers.image.source="https://github.com/aggrega-ai/aggrega-hub"
COPY --from=build /opt/agent /opt/agent
COPY quickstart /app/quickstart
COPY quickstart-ask /usr/local/bin/quickstart-ask
ENV PATH=/opt/agent/bin:$PATH \
    PYTHONPATH=/app \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1
WORKDIR /app
USER 10001:10001
EXPOSE 8000
CMD ["python", "-m", "quickstart.server"]
