FROM ubuntu:22.04

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
  openjdk-17-jdk \
  wget \
  ca-certificates \
  locales \
  && rm -rf /var/lib/apt/lists/*

ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64

# Flutter version (pin for reproducibility)
ENV FLUTTER_VERSION=3.19.6
ENV FLUTTER_HOME=/opt/flutter
ENV PATH="$FLUTTER_HOME/bin:$PATH"

# Download Flutter tarball
RUN mkdir -p /opt && cd /opt && \
  wget -q https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz -O flutter.tar.xz && \
  tar xf flutter.tar.xz && rm flutter.tar.xz

# Android SDK
ENV ANDROID_HOME=/opt/android-sdk
ENV ANDROID_SDK_ROOT=$ANDROID_HOME
ENV PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"

RUN mkdir -p $ANDROID_HOME/cmdline-tools && cd /tmp && \
  wget -q https://dl.google.com/android/repository/commandlinetools-linux-9477386_latest.zip -O commandlinetools.zip && \
  unzip -q commandlinetools.zip -d $ANDROID_HOME/cmdline-tools && \
  mv $ANDROID_HOME/cmdline-tools/cmdline-tools $ANDROID_HOME/cmdline-tools/latest && \
  rm commandlinetools.zip

# Install SDK components and accept licenses
RUN yes | sdkmanager --licenses || true && \
  sdkmanager "platform-tools" "platforms;android-30" "platforms;android-33" "build-tools;30.0.3" "build-tools;33.0.2" || true

# Configure flutter for web
RUN flutter doctor || true
RUN flutter config --enable-web || true

# Ensure git safe dir for Flutter install
RUN git config --global --add safe.directory /opt/flutter || true

# Working directory for project
WORKDIR /app

EXPOSE 8090

CMD ["sh", "-c", "flutter pub get && tail -f /dev/null"]
