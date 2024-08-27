FROM gitlab-registry.nrp-nautilus.io/prp/jupyter-stack/scipy:v1.3

USER root
WORKDIR /opt

# Update linux dependencies
RUN apt-get update -y \
 && apt-get install -y \
    libgl1-mesa-dev \
    libegl1-mesa-dev

# Install rclone
RUN curl https://rclone.org/install.sh | bash

# Switch back to jovyan for conda installs
USER $NB_USER
WORKDIR /opt/conda

# Update base conda env with packages for this image
COPY environment-gl.yaml environment-gl.yaml

RUN conda env update -n base -f environment-gl.yaml --prune \
 && rm environment-gl.yaml

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
 && export CUDAARCHS="80" \
 && export TFCONDAENV="/opt/conda/bin/conda" \
 && bash $TFSRCDIR/package/local/linux/install_env.sh \
 && source activate $TFENV \
 && bash /opt/conda/tissue-forge/package/local/linux/install_all.sh

# Update tissue forge env with packages for jupyter notebook support
COPY tf-env.yaml tf-env.yaml

RUN conda env update -p /opt/conda/tissue-forge_install/env/ -f tf-env.yaml --prune \
 && rm tf-env.yaml

# Link tissue forge env so conda can find it
RUN mkdir /opt/conda/envs \
 && ln -s /opt/conda/tissue-forge_install/env /opt/conda/envs/tissue-forge

WORKDIR /home/${NB_USER}
ENV LD_LIBRARY_PATH=/usr/local/cuda-11.7/compat:$LD_LIBRARY_PATH
ENV TFPYSITEDIR=/opt/conda/tissue-forge_install/lib/python3.8/site-packages/
ENV TFENV=/opt/conda/tissue-forge_install/env
ENV PYTHONPATH=$TFPYSITEDIR
