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

# Crear commit inicial vacío para poder hacer push
echo -e "${BLUE}📝 Creando commit inicial...${NC}"
git commit --allow-empty -m "chore: initialize ${BRANCH_NAME}"

# Push de la rama
echo -e "${BLUE}📤 Haciendo push de la rama...${NC}"
git push -u origin $BRANCH_NAME

# Calcular deadline
DEADLINE=$(date -d '+2 days' '+%Y-%m-%d %H:%M')
DEADLINE_UNIX=$(date -d '+2 days' '+%s')

# Preparar descripción de la PR
PR_BODY="## 🚀 Trunk-Based Development - Quick Branch

### ⏰ IMPORTANTE: DEADLINE DE 2 DÍAS
**📅 Fecha límite:** \`$DEADLINE\`

Esta rama debe mergearse a \`main\` en un máximo de **2 días** siguiendo las prácticas de Trunk-Based Development.

### 📋 Checklist
- [ ] Tests pasando ✅
- [ ] Cambios pequeños y atómicos
- [ ] Listo para merge en menos de 2 días

### 🎯 Recordatorios
- ⚠️ Si toma más de 2 días, **dividir en PRs más pequeños**
- 🔄 Main siempre debe estar deployable
- 💚 Auto-merge activado - solo necesita CI verde
- 📝 Commits frecuentes y pequeños

---
🤖 PR creada automáticamente por \`create-quick-branch.sh\`"

# Crear PR automáticamente
echo ""
echo -e "${YELLOW}═══════════════════════════════════════════════════${NC}"
echo -e "${GREEN}📨 Creando Pull Request...${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════════${NC}"
echo ""

PR_URL=$(gh pr create \
    --title "${PREFIX}: ${FEATURE_NAME}" \
    --body "$PR_BODY" \
    --base main \
    --head $BRANCH_NAME 2>&1)

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Pull Request creada exitosamente!${NC}"
    echo ""
    echo -e "${YELLOW}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║${NC}  ${GREEN}🎉 TU PULL REQUEST ESTÁ LISTA${NC}                         ${YELLOW}║${NC}"
    echo -e "${YELLOW}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}🔗 URL de la PR:${NC}"
    echo -e "   ${GREEN}$PR_URL${NC}"
    echo ""
    echo -e "${BLUE}📊 Información:${NC}"
    echo -e "  Rama: ${YELLOW}$BRANCH_NAME${NC}"
    echo -e "  Desde: ${YELLOW}main${NC}"
    echo -e "  Tipo: ${YELLOW}$PREFIX${NC}"
    echo ""
    echo -e "${RED}⏰ DEADLINE: $DEADLINE${NC}"
    echo ""
    
    # Intentar activar auto-merge
    echo -e "${BLUE}🤖 Activando auto-merge...${NC}"
    if gh pr merge --auto --squash "$PR_URL" 2>/dev/null; then
        echo -e "${GREEN}✅ Auto-merge activado! Se mergeará automáticamente cuando CI pase${NC}"
    else
        echo -e "${YELLOW}⚠️  Auto-merge no disponible - configúralo manualmente si es necesario${NC}"
    fi
    echo ""
else
    echo -e "${YELLOW}⚠️  No se pudo crear la PR automáticamente${NC}"
    echo -e "${BLUE}Puedes crearla manualmente con:${NC}"
    echo "  gh pr create --title '$PREFIX: $FEATURE_NAME' --body '...'"
fi

echo ""
echo -e "${YELLOW}═══════════════════════════════════════════════════${NC}"
echo -e "${BLUE}🚀 Próximos pasos:${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════════${NC}"
echo "  1. ✏️  Haz tus cambios en el código"
echo "  2. 💾 Commit frecuentemente: git commit -m 'feat: ...' "
echo "  3. 📤 Push: git push"
echo "  4. ✅ CI valida automáticamente"
echo "  5. 🎯 Auto-merge activado - se mergea solo cuando CI pase"
echo ""
echo -e "${GREEN}💡 Recuerda:${NC}"
echo -e "  ${RED}⚠️${NC}  Máximo 2 días de vida para esta rama"
echo "  📦 Si toma más tiempo, divide en PRs más pequeños"
echo "  🚀 Main siempre debe estar deployable"
echo "  💚 No requieres approvals, confía en el CI"
echo ""
