#!/bin/bash

# Esse scripte é usado para criar as imagens packer a partir do comando build. 
# O usuário deve passar como parâmetro o ambiente e o caminho do projeto. 
# Por exemplo ./build -e dev -d vm-packer-ol9. Neste caso -e indiga o ambiente e -d o caminho do projeto a ser construido.
#  Além disso, várias arquivos são usados como arquivos de variaveis que eles ficam na pasta shared.
# O script também faz a validação do ambiente e do caminho do projeto.

# Se o -e for igual a "dev", carrega as variaveis de desenvolvimento que ficam no arquivo .env.dev. Se for "prod", carrega as variaveis de produção que ficam no arquivo .env.prod.




