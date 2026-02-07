#!/bin/bash
# create-quick-branch.sh - Crea una rama de feature con recordatorio de 2 días

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}⚡ Trunk-Based Quick Branch Creator${NC}"
echo ""

# Verificar que estamos en un repo git
if [ ! -d .git ]; then
    echo -e "${RED}❌ Error: No estás en un repositorio git${NC}"
    exit 1
fi

# Asegurarse de estar en main actualizado
echo -e "${BLUE}📥 Actualizando main...${NC}"
git checkout main
git pull origin main

# Pedir nombre de la feature
echo -e "${GREEN}📝 Nombre de la feature (ej: login-page, fix-bug-123):${NC}"
read -p "Feature: " FEATURE_NAME

if [ -z "$FEATURE_NAME" ]; then
    echo -e "${RED}❌ Error: Debes ingresar un nombre${NC}"
    exit 1
fi

# Pedir tipo de branch
echo -e "${GREEN}📝 Tipo de cambio:${NC}"
echo "  1) feature - Nueva funcionalidad"
echo "  2) fix - Bug fix"
echo "  3) refactor - Refactorización"
echo "  4) docs - Documentación"
read -p "Selecciona (1-4): " BRANCH_TYPE

case $BRANCH_TYPE in
    1) PREFIX="feature" ;;
    2) PREFIX="fix" ;;
    3) PREFIX="refactor" ;;
    4) PREFIX="docs" ;;
    *) PREFIX="feature" ;;
esac

BRANCH_NAME="${PREFIX}/${FEATURE_NAME}"

# Verificar si la rama ya existe
if git show-ref --verify --quiet refs/heads/$BRANCH_NAME; then
    echo -e "${RED}❌ Error: La rama $BRANCH_NAME ya existe${NC}"
    exit 1
fi

# Crear rama
echo -e "${GREEN}🌿 Creando rama $BRANCH_NAME...${NC}"
git checkout -b $BRANCH_NAME

echo ""
echo -e "${GREEN}✅ Rama creada exitosamente!${NC}"
echo ""
echo -e "${BLUE}📊 Información:${NC}"
echo -e "  Rama: ${YELLOW}$BRANCH_NAME${NC}"
echo -e "  Desde: ${YELLOW}main${NC}"
echo ""
echo -e "${YELLOW}⏰ RECORDATORIO: Trunk-Based Development${NC}"
echo -e "  ⚠️  Esta rama debe vivir ${RED}máximo 2 días${NC}"
echo -e "  🎯 Objetivo: Merge rápido a main"
echo -e "  📝 Tip: Haz commits pequeños y frecuentes"
echo ""
echo -e "${BLUE}📅 Deadline:${NC}"
DEADLINE=$(date -d '+2 days' '+%Y-%m-%d %H:%M')
echo -e "  ${RED}$DEADLINE${NC}"
echo ""
echo -e "${BLUE}🚀 Próximos pasos:${NC}"
echo "  1. Haz tus cambios"
echo "  2. Commit frecuentemente: git commit -m 'feat: ...' "
echo "  3. Push: git push -u origin $BRANCH_NAME"
echo "  4. Crea PR: gh pr create --title '$PREFIX: $FEATURE_NAME' --body '...'"
echo "  5. CI valida automáticamente"
echo "  6. Auto-merge se activa"
echo ""
echo -e "${GREEN}💡 Recuerda:${NC}"
echo "  - Si toma más de 2 días, considera dividir en PRs más pequeños"
echo "  - Main siempre debe estar deployable"
echo "  - No requieres approvals, confía en el CI"
