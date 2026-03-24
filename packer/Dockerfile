# Use uma imagem base do Ubuntu
FROM assembleiarr/packer-alpine:latest
USER root
LABEL Name="Packer Provisionamento"

# Host que rodará o container do packer.
ARG PACKER_HOST
ENV PACKER_HOST=${PACKER_KS_PORT}

# Porta usada pelo kickstart de instalação do ol/rhel/centos
ARG PACKER_KS_PORT
ENV PACKER_KS_PORT=${PACKER_KS_PORT}
WORKDIR /workspace

EXPOSE ${PACKER_KS_PORT}
SHELL ["/bin/bash", "-c"]
# Comando padrão (opcional)
# CMD ["/bin/zsh"]
# CMD ["/bin/ash"]