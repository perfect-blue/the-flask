FROM python:3.9-slim-bullseye

# for run on macbook
# FROM --platform=linux/amd64 python:3.9-slim-bullseye

LABEL maintainer="Muhammad Ravi"

RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    # required for psycopg2 compilation (if not using library)
    libpq-dev \
    # runtime dependency for PostgresSQL
    libpq5 \
    # downloading UV
    curl \
    && curl -LsSf https://astral.sh/uv/install.sh | sh \
    && rm -rf /var/lib/apt/lists/*


# Add uv to PATH
ENV PATH="/root/.cargo/bin:${PATH}"

# Install Python dependencies
COPY dependencies.txt /dependencies.txt

RUN apt-get update && apt-get install -y --no-install-recommends \
    # for gcc
    build-essential \
    gcc \
    git \
    && python3.9 -m pip install -U --no-cache-dir pip \
    && uv pip install --python python3.9 -U -r /dependencies.txt \
    # must install separately due to NumPy must be installed earlier
    && uv pip install --python python3.9 Cython \
    && apt-get purge -y --auto-remove build-essential gcc git python3-dev curl \
    && rm /dependencies.txt \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user and share access to /src 
RUN groupadd -g 999 station && \
    useradd -r -u 999 -g station station
USER station

COPY --chown=station:station src/ /src
COPY --chown=station:station scripts/wait-for-it.sh /src

# Pass commit SHA from build
ARG COMMIT_SHA
ENV COMMIT_SHA=${COMMIT_SHA}

WORKDIR /src
RUN mkdir -p tmp/logs

EXPOSE 5000 8000

CMD ["flask", "--app", "app:app", "run", "--host", "0.0.0.0", "--port", "5000"]