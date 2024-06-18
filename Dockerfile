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

# Download and install Tissue Forge
RUN git clone --recurse-submodules https://github.com/tissue-forge/tissue-forge
RUN source /opt/conda/tissue-forge/package/local/linux/install_vars.sh
ENV TFSRCDIR=/opt/conda/tissue-forge
ENV TFENV=/opt/conda/tissue-forge_install/env
ENV TFBUILDDIR=/opt/conda/tissue-forge_build
ENV TFBUILDQUAL=local
ENV TFBUILD_CONFIG=Release
ENV TFINSTALLDIR=/opt/conda/tissue-forge_install
ENV TF_WITHCUDA="1"
ENV CUDAARCHS="80;89"
ENV TFCONDAENV="/opt/conda/bin/conda"
ENV PATH=/opt/conda/bin:$PATH
RUN bash $TFSRCDIR/package/local/linux/install_env.sh
RUN source activate $TFENV
RUN bash /opt/conda/tissue-forge/package/local/linux/install_all.sh

COPY environment.yml environment.yml

RUN conda env update -n base -f environment.yml --prune \
 && rm environment.yml

# RUN conda install -y -c conda-forge \
#     opencv \
#     gudhi \
#     tabulate \
#     ripser \
#     persim

# RUN conda install -y -c conda-forge -c tissue-forge tissue-forge
