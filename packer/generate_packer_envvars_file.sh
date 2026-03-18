#!/usr/bin/env bash

OUTPUT_FILE="packer_envvars.sh"
TEMP_ENV=".env.tmp.packer"

if [ ! -f ".env" ]; then
    echo "[ERRO] Arquivo .env não encontrado no diretório atual."
    exit 1
fi

# Cria um .env temporário:
# 1. Substitui // por #
# 2. Remove espaços ao redor do '='
sed 's|//|#|; s/^[[:space:]]*\([^[:space:]=]\+\)[[:space:]]*=[[:space:]]*/\1=/' .env > "$TEMP_ENV"

# Carrega variáveis do .env temporário
set -a
source "$TEMP_ENV"
set +a

echo "> Gerando $OUTPUT_FILE ..."

cat << EOF > "$OUTPUT_FILE"
#!/usr/bin/env bash
# Variáveis PKR_VAR (referenciando variáveis originais)

# Packer Logging
echo -e '\\n> Setting the Packer Logging...'
log_dir="/tmp/packer"
mkdir -p "\${log_dir}"
export PACKER_LOG=1
export PACKER_LOG_PATH="\${log_dir}/packer.log"
# export PACKER_HOST=192.168.0.1

EOF

while IFS= read -r line || [[ -n "$line" ]]; do
    # Ignora linhas vazias ou comentários (#)
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    # Ignora linhas que não possuem '='
    [[ ! "$line" =~ = ]] && continue

    # Extrai nome da variável (antes do '=')
    name=$(echo "$line" | cut -d '=' -f1 | xargs)

    # Escreve export usando referência (sem avaliar o valor)
    echo "export PKR_VAR_${name}=\"\${${name}}\"" >> "$OUTPUT_FILE"

done < "$TEMP_ENV"

chmod +x "$OUTPUT_FILE"
rm -f "$TEMP_ENV"  # Remove o .env temporário
echo "> Arquivo $OUTPUT_FILE gerado com sucesso!"
