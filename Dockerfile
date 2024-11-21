ARG BASE_IMAGE=quay.io/jupyter/scipy-notebook:2024-07-29
FROM ${BASE_IMAGE}

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

# Switch back to jovyan for conda installs
USER $NB_USER
WORKDIR /opt/conda

# Install nb_conda_kernels, cuda and dependencies for new tissue-forge env
RUN mamba install -y \
   nb_conda_kernels \
   cuda-version=12.4 \
   nvidia/label/cuda-12.4.0::cuda-runtime \
   nvidia/label/cuda-12.4.0::cuda-nvcc \
   tissue-forge::tissue-forge \
   ipyevents

# Download and install Tissue Forge
RUN git clone --recurse-submodules https://github.com/tissue-forge/tissue-forge
RUN source /opt/conda/tissue-forge/package/local/linux/install_vars.sh \
 && export TFSRCDIR=/opt/conda/tissue-forge \
 && export TFENV=/opt/conda/tissue-forge_install/env \
 && export TFBUILDDIR=/opt/conda/tissue-forge_build \
 && export TFBUILDQUAL=local \
 && export TFBUILD_CONFIG=Release \
 && export TFINSTALLDIR=/opt/conda/tissue-forge_install \
 && export TF_WITHCUDA="1" \
 && export CUDAARCHS="80;89" \
 && export TFCONDAENV="/opt/conda/bin/conda" \
 && bash $TFSRCDIR/package/local/linux/install_env.sh \
 && source activate $TFENV \
 && bash /opt/conda/tissue-forge/package/local/linux/install_all.sh

# Link tissue forge env so conda can find it
RUN mkdir /opt/conda/envs \
 && ln -s /opt/conda/tissue-forge_install/env /opt/conda/envs/tissue-forge

# Update tissue forge env with packages for jupyter notebook support
RUN mamba install -y -n tissue-forge \
   ipython \
   notebook \
   ipywidgets \
   ipyevents

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
ENV LD_LIBRARY_PATH=/usr/local/cuda-11.7/compat:$LD_LIBRARY_PATH
ENV TFPYSITEDIR=/opt/conda/tissue-forge_install/lib/python3.8/site-packages/
ENV TFENV=/opt/conda/tissue-forge_install/env
ENV PYTHONPATH=$TFPYSITEDIR
