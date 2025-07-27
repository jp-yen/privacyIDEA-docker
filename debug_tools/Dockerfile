FROM alpine/git

# 通信試験・デバッグ用のツールをインストール
RUN http_proxy="http://192.168.0.251:3128" apk update && apk upgrade && \
    apk add --no-cache \
    freeradius-utils \
    curl \
    wget \
    netcat-openbsd \
    bind-tools \
    iputils \
    tcpdump \
    tshark \
    traceroute \
    busybox-extras \
    openssh-client \
    net-tools \
    nmap \
    jq \
    bash \
    vim \
    less \
    htop \
    tree \
    postgresql-client \
    openldap-clients \
    perl \
    perl-file-temp

# 作業ディレクトリの設定
WORKDIR /debug

# ログディレクトリを作成
RUN mkdir -p /debug/logs

# デフォルトでbashを起動
CMD ["/bin/bash"]
