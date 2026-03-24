# Use uma imagem base do Ubuntu
#FROM assembleiarr/packer-alpine:latest
#USER root
FROM hashicorp/packer:1.12
LABEL Name="Packer Provisionamento"

# Copia o arquivo de plugins
COPY plugins /plugins
# Instala os plugins do packer
RUN packer init /plugins

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