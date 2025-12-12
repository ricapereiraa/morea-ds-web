# Imagem correta para Raspberry Pi 3 (ARMv7)
FROM balenalib/raspberrypi3-debian-python:3.11

ARG TARGETPLATFORM
ARG TARGETARCH
ARG BUILDPLATFORM
RUN echo "Building for ${TARGETPLATFORM} (${TARGETARCH}) from ${BUILDPLATFORM}"

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV DEBIAN_FRONTEND=noninteractive
ENV PIP_DISABLE_PIP_VERSION_CHECK=1
ENV TMPDIR=/tmp

WORKDIR /app

RUN apt-get update --fix-missing && apt-get install -y --no-install-recommends \
    apt-utils ca-certificates gnupg dirmngr \
    python3-dev \
    build-essential gcc gfortran \
    libatlas-base-dev \
    libopenblas-dev liblapack-dev \
    pkg-config \
    libjpeg62-turbo libjpeg62-turbo-dev \
    libjpeg-dev \
    zlib1g zlib1g-dev \
    libfreetype6 libfreetype6-dev \
    liblcms2-dev \
    libwebp-dev \
    libtiff-dev libopenjp2-7 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/* /tmp/*

COPY requirements.txt /app/

ENV PIP_EXTRA_INDEX_URL=https://www.piwheels.org/simple

RUN pip install --no-cache-dir meson meson-python ninja setuptools_scm

RUN pip install --no-cache-dir --prefer-binary numpy==1.26.4 \
    && pip install --no-cache-dir --prefer-binary plotly==5.19.0 \
    && pip install --no-cache-dir --prefer-binary -r /app/requirements.txt \
    && rm -rf ~/.cache/pip

RUN python - <<'PY'
import numpy
import plotly.graph_objects as go
print("numpy", numpy.__version__)
print("plotly OK")
try:
    import PIL
    print("pillow", PIL.__version__)
except Exception as exc:
    raise SystemExit(f"pillow import failed: {exc}")
PY

COPY . /app/

RUN mkdir -p /app/media /app/static

COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

COPY diagnose_imports.py /app/
COPY IMPORT_ERROR_FIX.md /app/

EXPOSE 8000

ENTRYPOINT ["/entrypoint.sh"]
