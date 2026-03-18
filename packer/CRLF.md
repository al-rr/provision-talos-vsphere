# Guia de Padronização de Final de Linha (LF vs CRLF)

Este guia garante que todos os arquivos do projeto utilizem LF (Unix) como final de linha.
Isso evita erros ao executar scripts em Linux, como:

/bin/bash^M: bad interpreter: No such file or directory
required file not found

Quando um arquivo é salvo com CRLF no Windows, o Linux pode não interpretar corretamente o #!/bin/bash, causando falhas ao executar scripts .sh.

## 1) Configurar o VS Code para salvar sempre em LF

No VS Code:

File → Preferences → Settings

Buscar por: End of Line

Selecionar: LF

Via settings.json:

Abrir: Ctrl+Shift+P → Preferences: Open Settings (JSON)

Adicionar:

"files.eol": "\n"

Verificar:

No canto inferior direito do VS Code, verifique se está como LF.

Se estiver CRLF, clique e altere para LF.

## 2) Configurar o Git para não converter linhas automaticamente

Executar no host (Windows):

git config --global core.autocrlf false
git config --global core.eol lf
git config --global core.safecrlf true

## 3) Converter arquivos existentes para LF

Instalar dos2unix se necessário:

Debian/Ubuntu: sudo apt install dos2unix
RHEL/CentOS/Oracle Linux: sudo yum install dos2unix

Converter apenas arquivos .sh:

find . -type f -name "*.sh" -exec dos2unix {} ;

Converter todos os arquivos (opcional):

find . -type f -exec dos2unix {} ;

## 4) Renormalizar o repositório

git add --renormalize .
git commit -m "Normalizando finais de linha para LF"

## 5) (Recomendado) Criar arquivo .editorconfig

Conteúdo sugerido:

[*]
end_of_line = lf
charset = utf-8
insert_final_newline = true

[*.sh]
indent_style = space
indent_size = 2

[*.yml]
indent_size = 2

[*.py]
indent_size = 4

6) Resumo

VS Code → salvar como LF

Git → core.autocrlf false

Converter arquivos → dos2unix

Renormalizar → git add --renormalize

Aplicar regra automática → .editorconfig