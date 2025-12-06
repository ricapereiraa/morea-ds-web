# Usar Python 3.11 slim (compatível com Raspberry Pi 3)
# RPi3 = armv7l, RPi4+ = aarch64
FROM python:3.11-slim

# Variáveis de ambiente para comportamentos do Python/apt/pip
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1
ENV DEBIAN_FRONTEND=noninteractive
ENV DEBCONF_NONINTERACTIVE_SEEN=true
ENV PIP_DISABLE_PIP_VERSION_CHECK=1
ENV TMPDIR=/tmp

WORKDIR /app

# Garantir diretórios de cache do apt e instalar dependências mínimas
# Usa --allow-unauthenticated para contornar problemas de GPG em ambientes RPi isolados
RUN set -eux; \
    mkdir -p /var/cache/apt/archives/partial /var/cache/apt/archives /var/lib/apt/lists; \
    rm -rf /var/lib/apt/lists/*; \
    apt-get clean; \
    apt-get update -o Acquire::AllowInsecureRepositories=true -o Acquire::AllowDowngradeToInsecureRepositories=true || true; \
    apt-get install -y --allow-unauthenticated --no-install-recommends \
        apt-utils ca-certificates gnupg dirmngr \
        build-essential gcc gfortran \
        libopenblas-dev libopenblas0 \
        liblapack-dev liblapack3 \
        pkg-config; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY requirements.txt /app/

# Usar piwheels como índice extra para Raspberry Pi (wheels pré-compiladas)
ENV PIP_EXTRA_INDEX_URL=https://www.piwheels.org/simple

# Instalar dependências do build (meson, meson-python, ninja)
RUN pip install --no-cache-dir --progress-bar off meson meson-python ninja setuptools_scm

# Instalar dependências Python na ordem: numpy -> pandas -> plotly -> demais
RUN pip cache purge || true && \
    pip install --no-cache-dir --progress-bar off --index-url https://pypi.org/simple numpy==1.26.4 && \
    pip install --no-cache-dir --progress-bar off --index-url https://pypi.org/simple pandas==2.2.0 && \
    pip install --no-cache-dir --progress-bar off --index-url https://pypi.org/simple plotly==5.19.0 && \
    pip install --no-cache-dir --progress-bar off --extra-index-url "${PIP_EXTRA_INDEX_URL}" -r /app/requirements.txt && \
    rm -rf /tmp/* /var/tmp/* ~/.cache/pip && \
    find /usr/local/lib/python3.11 -type d -name "__pycache__" -delete 2>/dev/null || true && \
    find /usr/local/lib/python3.11 -name "*.pyc" -delete 2>/dev/null || true

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
