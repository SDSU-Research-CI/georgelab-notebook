FROM gitlab-registry.nrp-nautilus.io/prp/jupyter-stack/scipy:v1.3

USER root

WORKDIR /opt

# Install rclone
RUN curl https://rclone.org/install.sh | bash

USER $NB_USER

WORKDIR /home/${NB_USER}

RUN conda install -y -c conda-forge \
    opencv \
    gudhi \
    tabulate \
    ripser \
    persim
