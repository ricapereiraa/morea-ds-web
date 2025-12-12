FROM balenalib/raspberrypi3-debian-python:3.10-bullseye-run

ARG TARGETPLATFORM
ARG TARGETARCH
ARG BUILDPLATFORM
RUN echo "Building for ${TARGETPLATFORM} (${TARGETARCH}) from ${BUILDPLATFORM}"

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Instalar dependências do sistema (compatível com HypriotOS v1.12.3 - GLIBC 2.31)
RUN install_packages \
    build-essential \
    python3-dev \
    python3-pip \
    curl \
    libatlas-base-dev \
    libopenblas-dev \
    liblapack-dev \
    libjpeg62-turbo-dev \
    zlib1g-dev \
    libfreetype6-dev \
    liblcms2-dev \
    libwebp-dev \
    libtiff5-dev \
    libopenjp2-7 \
    libffi-dev \
    pkg-config \
    gcc \
    gfortran \
    meson \
    ninja-build

WORKDIR /app

COPY requirements.txt .

# Reinstalar pip usando get-pip.py (o pip da imagem base está quebrado)
RUN curl -sS https://bootstrap.pypa.io/get-pip.py | python3 && \
    pip3 install --no-cache-dir --upgrade setuptools wheel

# Instalar meson e meson-python para compilar numpy
RUN pip install --no-cache-dir meson meson-python ninja

# Instalar numpy compilando do código-fonte para compatibilidade com GLIBC 2.31
# numpy 1.22.4 é compatível com Python 3.10 e GLIBC 2.31 (compilado do código-fonte)
# Forçamos compilação do código-fonte para garantir compatibilidade com GLIBC 2.31
RUN pip install --no-cache-dir --no-binary numpy numpy==1.22.4

# Instalar pillow e plotly com versões compatíveis com GLIBC 2.31
RUN pip install --no-cache-dir \
    pillow==9.0.1 \
    plotly==5.18.0

# Instalar outras dependências do requirements.txt (bibliotecas Python puras não dependem do GLIBC)
# Mas precisamos substituir numpy, pillow e plotly pelas versões compatíveis
RUN pip install --no-cache-dir \
    asgiref==3.7.2 \
    Django==5.0.1 \
    django-crontab==0.7.1 \
    django-extensions==3.2.3 \
    django-stubs==4.2.7 \
    django-stubs-ext==4.2.7 \
    djangorestframework==3.14.0 \
    gunicorn==22.0.0 \
    packaging==23.2 \
    PyMySQL==1.1.1 \
    pynvim==0.5.0 \
    python-dateutil==2.8.2 \
    python-dotenv==1.0.1 \
    pytz==2024.1 \
    six==1.16.0 \
    sqlparse==0.5.0 \
    tenacity==8.2.3 \
    types-pytz==2024.1.0.20240203 \
    types-PyYAML==6.0.12.12 \
    typing_extensions==4.10.0 \
    tzdata==2024.1 \
    cryptography \
    prometheus-client==0.19.0

# Verificar instalação das bibliotecas críticas
RUN python3 - <<'PY'
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

COPY . .

CMD ["python3", "main.py"]
