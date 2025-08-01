ARG BASE_IMAGE=quay.io/jupyter/scipy-notebook:2025-07-07

FROM nvidia/cuda:12.9.0-cudnn-devel-ubuntu22.04 AS tf_build

# Set bash as default shell
RUN ln -sf /bin/bash /bin/sh

# Update linux dependencies
RUN apt-get update -y \
 && apt-get install -y \
    libgl1-mesa-dev \
    libegl1-mesa-dev \
    curl \
    wget \
    git \
    vim \
 && apt clean \
 && rm -rf /var/lib/apt/lists/*

# Install miniconda
RUN mkdir -p ~/miniconda3 \
 && wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda3/miniconda.sh \
 && bash ~/miniconda3/miniconda.sh -b -u -p ~/miniconda3 \
 && rm ~/miniconda3/miniconda.sh \
 && source ~/miniconda3/bin/activate \
 && conda init --all \
 && conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main \
 && conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r
ENV PATH="/root/miniconda3/bin:${PATH}"

# Install tissue forge
WORKDIR /opt
RUN git clone --recurse-submodules https://github.com/tissue-forge/tissue-forge
RUN chmod +x /opt/tissue-forge/package/local/linux/install_all.sh
RUN source /opt/tissue-forge/package/local/linux/install_vars.sh \
 && export TFSRCDIR=/opt/tissue-forge \
 && export TFENV=/opt/tissue-forge_install/env \
 && export TFBUILDDIR=/opt/tissue-forge_build \
 && export TFBUILDQUAL=local \
 && export TFBUILD_CONFIG=Debug \
 && export TFINSTALLDIR=/opt/tissue-forge_install \
 && export TF_WITHCUDA=1 \
 && export CUDAARCHS="80;89" \
 && conda create --yes --prefix $TFENV \
 && conda env update --prefix $TFENV --file $TFSRCDIR/package/local/linux/env.yml \
 && source activate $TFENV \
 && bash /opt/tissue-forge/package/local/linux/install_all.sh

FROM ${BASE_IMAGE} AS notebook

# Switch to root for updates and installs
USER root
WORKDIR /opt

# Update linux dependencies
RUN apt-get update -y \
 && apt-get install -y \
    libgl1-mesa-dev \
    libegl1-mesa-dev \
 && apt clean \
 && rm -rf /var/lib/apt/lists/* \
 && fix-permissions "${CONDA_DIR}" \
 && fix-permissions "/home/${NB_USER}"

# Install rclone
RUN curl https://rclone.org/install.sh | bash

# Install VS Code Server
RUN curl -fsSL https://code-server.dev/install.sh | sh

# Copy pre-built tissue forge
RUN mkdir -p /opt/tissue-forge_install
COPY --from=tf_build /opt/tissue-forge_install /opt/tissue-forge_install

# Link tissue forge env so conda can find it
RUN mkdir /opt/conda/envs \
 && ln -s /opt/tissue-forge_install/env /opt/conda/envs/tissue-forge
RUN chown -R 1000:100 /opt/tissue-forge_install

# Switch back to jovyan for conda installs
USER $NB_USER
WORKDIR /opt/conda

# Install nb_conda_kernels, cuda and dependencies for new tissue-forge env
RUN mamba install -y -n base \
   nb_conda_kernels \
   ipyevents

# Update tissue forge env with packages for jupyter notebook support
RUN mamba install -y -p /opt/conda/envs/tissue-forge \
   ipython \
   notebook \
   ipywidgets \
   ipyevents \
   cuda-version=12.9 \
   cuda-cudart \
   nvidia/label/cuda-12.9.0::cuda-runtime \
   nvidia/label/cuda-12.9.0::cuda-nvcc \
   nvidia/label/cuda-12.9.0::cuda-cudart \
   nvidia/label/cuda-12.9.0::cuda-nvrtc

# Install VS Code Server proxy
RUN pip install \
   jupyter-codeserver-proxy

# Install George lab packages
RUN mamba install -y -n base \
   opencv \
   gudhi \
   tabulate \
   ripser \
   persim 

# Set Tissue Forge env vars
WORKDIR /home/${NB_USER}
ENV TFPYSITEDIR=/opt/tissue-forge_install/lib/python3.10/site-packages/
ENV TFENV=/opt/tissue-forge_install/env
ENV PYTHONPATH=$TFPYSITEDIR
