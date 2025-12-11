# Usar Python 3.11 slim (multi-arch: inclui arm/v7 para RPi3)
FROM --platform=$TARGETPLATFORM python:3.11-slim

# Build args úteis para multi-arch (registrado no log da build)
ARG TARGETPLATFORM
ARG TARGETARCH
ARG BUILDPLATFORM
RUN echo "Building for ${TARGETPLATFORM} (${TARGETARCH}) from ${BUILDPLATFORM}"

# Variáveis de ambiente para comportamentos do Python/apt/pip
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1
ENV DEBIAN_FRONTEND=noninteractive
ENV DEBCONF_NONINTERACTIVE_SEEN=true
ENV PIP_DISABLE_PIP_VERSION_CHECK=1
ENV TMPDIR=/tmp

WORKDIR /app

# Garantir diretórios de cache do apt e instalar dependências mínimas
# Forçamos update com retries e evitamos pacotes parcialmente baixados (causa comum de dpkg erro 1)
RUN set -eux; \
    mkdir -p /var/cache/apt/archives/partial /var/cache/apt/archives /var/lib/apt/lists; \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*; \
    apt-get update -o Acquire::Retries=3 -o Acquire::http::Timeout=30; \
    apt-get install -y --no-install-recommends \
        apt-utils ca-certificates gnupg dirmngr \
        build-essential gcc gfortran \
        libopenblas-dev libopenblas0 \
        liblapack-dev liblapack3 \
        pkg-config; \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/* /tmp/* /var/tmp/*

COPY requirements.txt /app/

# Usar piwheels como índice extra para Raspberry Pi (wheels pré-compiladas)
ENV PIP_EXTRA_INDEX_URL=https://www.piwheels.org/simple

# Instalar dependências do build (meson, meson-python, ninja)
RUN pip install --no-cache-dir --progress-bar off meson meson-python ninja setuptools_scm

# Instalar dependências Python principais e validar imports críticos
RUN pip cache purge || true && \
    pip install --no-cache-dir --progress-bar off --extra-index-url "${PIP_EXTRA_INDEX_URL}" numpy==1.26.4 && \
    pip install --no-cache-dir --progress-bar off --extra-index-url "${PIP_EXTRA_INDEX_URL}" plotly==5.19.0 && \
    pip install --no-cache-dir --progress-bar off --extra-index-url "${PIP_EXTRA_INDEX_URL}" -r /app/requirements.txt && \
    rm -rf /tmp/* /var/tmp/* ~/.cache/pip && \
    find /usr/local/lib/python3.11 -type d -name "__pycache__" -delete 2>/dev/null || true && \
    find /usr/local/lib/python3.11 -name "*.pyc" -delete 2>/dev/null || true

RUN python - <<'PY'
import numpy
import plotly.graph_objects as go

print("✓ numpy", numpy.__version__)
print("✓ plotly", go.__name__)
PY

COPY . /app/

# ensure media/static folders exist and are writable
RUN mkdir -p /app/media /app/static

# copy entrypoint
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Copy diagnostic scripts
COPY diagnose_imports.py /app/
COPY IMPORT_ERROR_FIX.md /app/

EXPOSE 8000

ENTRYPOINT ["/entrypoint.sh"]
