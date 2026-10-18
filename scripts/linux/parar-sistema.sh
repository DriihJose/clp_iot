#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/../../docker-compose.yml" ]; then
    ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
else
    ROOT_DIR="$SCRIPT_DIR"
fi
cd "$ROOT_DIR"

echo "================================================================="
echo "   PARANDO CONTEINERES DO DOCKER (LINUX)...                      "
echo "   Diretorio: $ROOT_DIR                                          "
echo "================================================================="
docker compose down
echo "Todos os servicos SCADA foram finalizados com sucesso!"