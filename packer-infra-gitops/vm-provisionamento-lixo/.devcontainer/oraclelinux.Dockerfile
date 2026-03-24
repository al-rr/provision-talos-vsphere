# Use uma imagem base do Ubuntu
FROM packer-oraclelinux:latest
USER root
LABEL Name=packer-provisionamento

# Copia o script de instalação para dentro da imagem
# Dá permissão de execução e executa o script
# COPY scripts/packer-oraclelinux.sh /tmp/packer-oraclelinux.sh
# RUN chmod +x /tmp/packer-oraclelinux.sh && /tmp/packer-oraclelinux.sh
RUN dnf install -y glibc gcc
# Defina o diretório de trabalho
WORKDIR /workspace

# Comando padrão (opcional)
CMD ["/bin/bash"]

# CMD ["/bin/zsh"]
# CMD ["/bin/ash"]