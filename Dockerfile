# Install npm packages
FROM node:10.17.0-alpine AS npm
WORKDIR /code
COPY ./static/package*.json /code/static/
RUN cd /code/static && npm ci

# FROM --platform=linux/amd64 ubuntu:22.04
FROM ubuntu:22.04

ARG RYE_VERSION="0.43.0"
ARG RYE_HASH_x86_64="ca702c3d93fd6ec76a1a0efaaa605e10736ee79a0674d241aad1bc0fe26f7d80"
ARG RYE_HASH_aarch64="72db8238de446f300a1a9eb9d76caa05a8429aeb3315ae5de606462b9da20c5a"
ARG TARGETARCH

# RUN export RYE_HASH=$(if [ "$TARGETARCH" = "amd64" ]; then echo "$RYE_HASH_amd64"; elif [ "$TARGETARCH" = "arm64" ]; then echo "$RYE_HASH_arm64"; else echo "Unsupported TARGETARCH: $TARGETARCH" && exit 1; fi) && echo "Using RYE_HASH=$RYE_HASH"

# Turns off buffering for easier container logging
ENV PYTHONUNBUFFERED=1

WORKDIR /code

# Copy dependency files
COPY pyproject.toml requirements.lock requirements-dev.lock .python-version ./

# Install deps
RUN apt-get update \
    && apt-get install -y curl netcat-traditional gcc python3-dev gnupg git libre2-dev build-essential pkg-config cmake ninja-build bash clang \
    && if [ "$TARGETARCH" = "amd64" ]; then \
        curl -sSL "https://github.com/astral-sh/rye/releases/download/${RYE_VERSION}/rye-x86_64-linux.gz" > rye.gz \
        && echo "${RYE_HASH_x86_64}  rye.gz" | sha256sum -c - ; \
    elif [ "$TARGETARCH" = "arm64" ]; then \
        curl -sSL "https://github.com/astral-sh/rye/releases/download/${RYE_VERSION}/rye-aarch64-linux.gz" > rye.gz \
        && echo "${RYE_HASH_aarch64}  rye.gz" | sha256sum -c - ; \
    else \
        echo "compatible arch not detected" ; \
    fi \
    && gunzip rye.gz \
    && chmod +x rye \
    && mv rye /usr/bin/rye \
    && rye toolchain fetch `cat .python-version` \
    && rye sync --no-lock --no-dev \
    && apt-get autoremove -y \
    && apt-get purge -y curl netcat-traditional build-essential pkg-config cmake ninja-build python3-dev clang \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Copy code
COPY . .

# copy npm packages
COPY --from=npm /code /code

ENV PATH="/code/.venv/bin:$PATH"
EXPOSE 7777

#gunicorn wsgi:app -b 0.0.0.0:7777 -w 2 --timeout 15 --log-level DEBUG
CMD ["gunicorn","wsgi:app","-b","0.0.0.0:7777","-w","2","--timeout","15"]
