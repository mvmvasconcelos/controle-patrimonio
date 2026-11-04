FROM ubuntu:22.04 AS flutter-sdk

# Non-interactive
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=America/Sao_Paulo

RUN apt-get update && apt-get install -y \
  curl \
  git \
  unzip \
  xz-utils \
  zip \
  libglu1-mesa \
  wget \
  ca-certificates \
  locales \
  && rm -rf /var/lib/apt/lists/*

# Flutter version (pin for reproducibility)
ENV FLUTTER_VERSION=3.29.2
ENV FLUTTER_HOME=/opt/flutter
ENV PATH="$FLUTTER_HOME/bin:$PATH"

# Download Flutter tarball
RUN mkdir -p /opt && cd /opt && \
  wget -q https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz -O flutter.tar.xz && \
  tar xf flutter.tar.xz && rm flutter.tar.xz

# Configure flutter for web
RUN flutter config --enable-web || true

# Ensure git safe dir for Flutter install
RUN git config --global --add safe.directory /opt/flutter || true

# Working directory for project
WORKDIR /app

EXPOSE 8090

CMD ["sh", "-c", "flutter pub get && tail -f /dev/null"]

FROM flutter-sdk AS web-builder

COPY . /app
RUN flutter pub get && flutter build web --release --base-href /controle-patrimonio/

FROM nginx:alpine AS web

COPY --from=web-builder /app/build/web/ /usr/share/nginx/html/controle-patrimonio/
COPY nginx/webapp.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
