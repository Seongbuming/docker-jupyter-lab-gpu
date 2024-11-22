# Ubuntu 베이스 이미지 사용
FROM ubuntu:22.04

# 타임존 설정
ENV TZ=Asia/Seoul
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# 필요한 패키지 설치
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    curl \
    vim \
    && rm -rf /var/lib/apt/lists/*

# NVIDIA CUDA 설치
RUN apt-get update && apt-get install -y --no-install-recommends \
    gnupg2 \
    curl \
    ca-certificates && \
    curl -fsSL https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb -O && \
    dpkg -i cuda-keyring_1.1-1_all.deb && \
    apt-get update && apt-get install -y --no-install-recommends \
    cuda-toolkit-12-3 && \
    rm -rf /var/lib/apt/lists/*

# Python 패키지 설치
RUN pip3 install --no-cache-dir \
    jupyter \
    jupyterlab \
    numpy \
    pandas \
    matplotlib \
    seaborn \
    scikit-learn \
    tensorflow \
    torch torchvision torchaudio

# 사용자 생성
RUN useradd -m -s /bin/bash -u 1000 user && \
    mkdir -p /home/user/work && \
    chown -R user:user /home/user

# 사용자 전환
USER user
WORKDIR /home/user

# Jupyter 설정
RUN mkdir -p /home/user/.jupyter && \
    echo "c.ServerApp.allow_origin = '*'" > /home/user/.jupyter/jupyter_server_config.py && \
    echo "c.ServerApp.ip = '0.0.0.0'" >> /home/user/.jupyter/jupyter_server_config.py && \
    echo "c.ServerApp.allow_root = True" >> /home/user/.jupyter/jupyter_server_config.py && \
    echo "c.ServerApp.root_dir = '/home/user/work'" >> /home/user/.jupyter/jupyter_server_config.py && \
    echo "c.ServerApp.allow_remote_access = True" >> /home/user/.jupyter/jupyter_server_config.py && \
    echo "c.ServerApp.token = ''" >> /home/user/.jupyter/jupyter_server_config.py && \
    chmod 700 /home/user/.jupyter

# 권한 설정
ENV HOME=/home/user \
    SHELL=/bin/bash \
    NB_USER=user \
    NB_UID=1000

EXPOSE 8888

# Jupyter Lab 실행
CMD ["jupyter", "lab", "--ip=0.0.0.0", "--port=8888", "--no-browser"]
