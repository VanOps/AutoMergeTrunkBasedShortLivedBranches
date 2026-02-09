#!/bin/bash
# check-trunk-health.sh - Verifica la salud del trunk (main)

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🌳 Trunk Health Monitor${NC}"
echo ""

# Verificar gh CLI
if ! command -v gh &> /dev/null; then
    echo -e "${RED}❌ Error: gh CLI no está instalado${NC}"
    exit 1
fi

echo -e "${GREEN}📊 Trunk (main) Health Report${NC}"
echo ""

# 1. Verificar estado de main
echo -e "${BLUE}1️⃣  Main Branch Status${NC}"
git checkout main -q
git pull origin main -q

LAST_COMMIT=$(git log -1 --pretty=format:"%h - %s (%ar)")
echo -e "  Last commit: ${GREEN}$LAST_COMMIT${NC}"
echo ""

# 2. Contar ramas activas
echo -e "${BLUE}2️⃣  Active Branches${NC}"
TOTAL_BRANCHES=$(git branch -r | grep -v 'HEAD\|main' | wc -l)
echo -e "  Total branches: ${YELLOW}$TOTAL_BRANCHES${NC}"

# Branches más antiguas que 2 días
TWO_DAYS_AGO=$(date -d '2 days ago' +%s)
OLD_COUNT=0

for branch in $(git branch -r | grep -v 'HEAD\|main' | sed 's/origin\///'); do
  LAST_COMMIT_DATE=$(git log -1 --format=%ct origin/$branch)
  if [ $LAST_COMMIT_DATE -lt $TWO_DAYS_AGO ]; then
    ((OLD_COUNT++))
  fi
done

if [ $OLD_COUNT -gt 0 ]; then
  echo -e "  Old branches (>2 days): ${RED}$OLD_COUNT${NC} ⚠️"
else
  echo -e "  Old branches (>2 days): ${GREEN}0${NC} ✅"
fi
echo ""

# 3. PRs abiertos
echo -e "${BLUE}3️⃣  Open Pull Requests${NC}"
OPEN_PRS=$(gh pr list --state open --json number,title,createdAt,author)
PR_COUNT=$(echo "$OPEN_PRS" | jq 'length')

echo -e "  Total PRs: ${YELLOW}$PR_COUNT${NC}"

if [ $PR_COUNT -gt 0 ]; then
  echo "$OPEN_PRS" | jq -r '.[] | "  - #\(.number): \(.title) (@\(.author.login))"'
fi
echo ""

# 4. Build status de main
echo -e "${BLUE}4️⃣  CI/CD Status (Main)${NC}"
LAST_RUN=$(gh run list --branch main --limit 1 --json conclusion,createdAt,workflowName --jq '.[0]')

if [ -n "$LAST_RUN" ]; then
  CONCLUSION=$(echo "$LAST_RUN" | jq -r '.conclusion')
  WORKFLOW=$(echo "$LAST_RUN" | jq -r '.workflowName')
  
  if [ "$CONCLUSION" == "success" ]; then
    echo -e "  Last CI: ${GREEN}✅ $WORKFLOW (passed)${NC}"
  else
    echo -e "  Last CI: ${RED}❌ $WORKFLOW (failed)${NC}"
  fi
else
  echo -e "  Last CI: ${YELLOW}No recent runs${NC}"
fi
echo ""

# 5. Deployment status
echo -e "${BLUE}5️⃣  Deployment Status${NC}"
echo -e "  Staging: ${GREEN}https://staging.tuapp.com${NC}"
echo -e "  Production: ${BLUE}Manual deployment required${NC}"
echo ""

# 6. Métricas de velocidad
echo -e "${BLUE}6️⃣  Development Velocity${NC}"
COMMITS_TODAY=$(git log --since="1 day ago" --oneline | wc -l)
COMMITS_WEEK=$(git log --since="1 week ago" --oneline | wc -l)

echo -e "  Commits today: ${YELLOW}$COMMITS_TODAY${NC}"
echo -e "  Commits this week: ${YELLOW}$COMMITS_WEEK${NC}"
echo ""

# Resumen final
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}📊 Summary${NC}"

HEALTH_SCORE=100

if [ $OLD_COUNT -gt 0 ]; then
  ((HEALTH_SCORE -= 20))
  echo -e "${RED}⚠️  $OLD_COUNT branches older than 2 days${NC}"
fi

if [ $PR_COUNT -gt 5 ]; then
  ((HEALTH_SCORE -= 10))
  echo -e "${YELLOW}⚠️  $PR_COUNT open PRs (consider merging faster)${NC}"
fi

if [ $COMMITS_TODAY -eq 0 ]; then
  ((HEALTH_SCORE -= 10))
  echo -e "${YELLOW}⚠️  No commits today${NC}"
fi

echo ""
if [ $HEALTH_SCORE -ge 80 ]; then
  echo -e "${GREEN}✅ Trunk health: GOOD ($HEALTH_SCORE/100)${NC}"
elif [ $HEALTH_SCORE -ge 60 ]; then
  echo -e "${YELLOW}⚠️  Trunk health: FAIR ($HEALTH_SCORE/100)${NC}"
else
  echo -e "${RED}❌ Trunk health: POOR ($HEALTH_SCORE/100)${NC}"
fi

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
