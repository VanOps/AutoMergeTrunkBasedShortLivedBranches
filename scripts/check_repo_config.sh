#!/bin/bash
# check-repo-config.sh - Trunk-Based Development Configuration Checker

REPO="$1"
if [ -z "$REPO" ]; then
  REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
fi

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║  Trunk-Based Development Auto-Merge Configuration Check   ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""
echo "📁 Repository: $REPO"
echo ""
echo "ℹ️  Strategy: Trunk-Based with Short-Lived Branches (max 2 days)"
echo ""

echo "🌿 Required Branch:"
# En trunk-based solo necesitamos main
if gh api repos/$REPO/branches/main >/dev/null 2>&1; then
  echo "  ✅ main exists"
  MAIN_EXISTS=true
else
  echo "  ❌ main missing - CRITICAL"
  MAIN_EXISTS=false
fi

echo ""
echo "📋 Workflow Files:"
WORKFLOW_FOUND=0
WORKFLOWS_MISSING=()

if [ -f ".github/workflows/trunk-ci.yml" ]; then
  echo "  ✅ trunk-ci.yml exists"
  WORKFLOW_FOUND=$((WORKFLOW_FOUND + 1))
else
  echo "  ❌ trunk-ci.yml missing"
  WORKFLOWS_MISSING+=("trunk-ci.yml")
fi

if [ -f ".github/workflows/fast-automerge.yml" ]; then
  echo "  ✅ fast-automerge.yml exists"
  WORKFLOW_FOUND=$((WORKFLOW_FOUND + 1))
else
  echo "  ⚠️  fast-automerge.yml missing (recommended)"
  WORKFLOWS_MISSING+=("fast-automerge.yml")
fi

if [ -f ".github/workflows/stale-branches.yml" ]; then
  echo "  ✅ stale-branches.yml exists"
  WORKFLOW_FOUND=$((WORKFLOW_FOUND + 1))
else
  echo "  ⚠️  stale-branches.yml missing (recommended)"
fi

echo ""
echo "🤖 GitHub Actions Permissions:"
ACTIONS_PERMS=$(gh api repos/$REPO/actions/permissions)
ACTIONS_ENABLED=$(echo "$ACTIONS_PERMS" | jq -r '.enabled')
CAN_APPROVE=$(echo "$ACTIONS_PERMS" | jq -r '.can_approve_pull_request_reviews')
DEFAULT_WORKFLOW_PERMS=$(echo "$ACTIONS_PERMS" | jq -r '.default_workflow_permissions')

# Detectar si los campos existen en la respuesta de la API
CAN_APPROVE_AVAILABLE=true
WORKFLOW_PERMS_AVAILABLE=true

if [ "$CAN_APPROVE" == "null" ] || [ -z "$CAN_APPROVE" ]; then
  CAN_APPROVE_AVAILABLE=false
  CAN_APPROVE="N/A"
fi

if [ "$DEFAULT_WORKFLOW_PERMS" == "null" ] || [ -z "$DEFAULT_WORKFLOW_PERMS" ]; then
  WORKFLOW_PERMS_AVAILABLE=false
  DEFAULT_WORKFLOW_PERMS="N/A"
fi

echo "  Actions enabled: $ACTIONS_ENABLED"
echo "  Default permissions: $DEFAULT_WORKFLOW_PERMS"
echo "  Can create and approve PRs: $CAN_APPROVE"

echo ""
echo "🔀 Merge Settings:"
REPO_INFO=$(gh api repos/$REPO)
ALLOW_MERGE_COMMIT=$(echo "$REPO_INFO" | jq -r '.allow_merge_commit')
ALLOW_SQUASH_MERGE=$(echo "$REPO_INFO" | jq -r '.allow_squash_merge')
ALLOW_REBASE_MERGE=$(echo "$REPO_INFO" | jq -r '.allow_rebase_merge')
AUTO_MERGE=$(echo "$REPO_INFO" | jq -r '.allow_auto_merge')
DELETE_BRANCH=$(echo "$REPO_INFO" | jq -r '.delete_branch_on_merge')

echo "  Merge commit allowed: $ALLOW_MERGE_COMMIT"
echo "  Squash merge allowed: $ALLOW_SQUASH_MERGE"
echo "  Rebase merge allowed: $ALLOW_REBASE_MERGE"
echo "  Auto-merge enabled: $AUTO_MERGE"
echo "  Auto-delete head branches: $DELETE_BRANCH"

echo ""
echo "🔒 Branch Protection (main):"
if [ "$MAIN_EXISTS" == "true" ]; then
  MAIN_PROTECTION=$(gh api repos/$REPO/branches/main/protection 2>/dev/null)
  if [ $? -eq 0 ]; then
    REQUIRE_PR=$(echo "$MAIN_PROTECTION" | jq -r '.required_pull_request_reviews != null')
    APPROVALS=$(echo "$MAIN_PROTECTION" | jq -r '.required_pull_request_reviews.required_approving_review_count // 0')
    DISMISS_STALE=$(echo "$MAIN_PROTECTION" | jq -r '.required_pull_request_reviews.dismiss_stale_reviews // false')
    
    REQUIRE_CHECKS=$(echo "$MAIN_PROTECTION" | jq -r '.required_status_checks != null')
    STRICT_CHECKS=$(echo "$MAIN_PROTECTION" | jq -r '.required_status_checks.strict // false')
    REQUIRED_CHECKS=$(echo "$MAIN_PROTECTION" | jq -r '.required_status_checks.checks // [] | length')
    
    LINEAR_HISTORY=$(echo "$MAIN_PROTECTION" | jq -r '.required_linear_history.enabled // false')
    ALLOW_FORCE_PUSH=$(echo "$MAIN_PROTECTION" | jq -r '.allow_force_pushes.enabled // false')
    ALLOW_DELETIONS=$(echo "$MAIN_PROTECTION" | jq -r '.allow_deletions.enabled // false')
    CONVERSATION_RESOLUTION=$(echo "$MAIN_PROTECTION" | jq -r '.required_conversation_resolution.enabled // false')
    
    echo "  ✅ Protected"
    echo "  Require PRs: $REQUIRE_PR"
    echo "  Required approvals: $APPROVALS (trunk-based: 0-1 recommended)"
    echo "  Dismiss stale approvals: $DISMISS_STALE"
    echo "  Require status checks: $REQUIRE_CHECKS"
    echo "  Require up-to-date: $STRICT_CHECKS"
    echo "  Status checks count: $REQUIRED_CHECKS"
    echo "  Linear history: $LINEAR_HISTORY (recommended for trunk-based)"
    echo "  Conversation resolution: $CONVERSATION_RESOLUTION"
    echo "  Allow force pushes: $ALLOW_FORCE_PUSH (should be false)"
    echo "  Allow deletions: $ALLOW_DELETIONS (should be false)"
    
    if [ "$REQUIRED_CHECKS" -gt 0 ]; then
      echo ""
      echo "  Required status checks:"
      echo "$MAIN_PROTECTION" | jq -r '.required_status_checks.checks[]? | "    - \(.context)"'
    fi
  else
    echo "  ❌ No protection rules configured - CRITICAL"
    REQUIRE_PR="false"
    REQUIRE_CHECKS="false"
  fi
else
  echo "  ⚠️  Cannot check - main branch doesn't exist"
fi

echo ""
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║              Configuration Issues Found                    ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# Check critical settings for Trunk-Based Development
ISSUES_FOUND=0
WARNINGS=0

# 1. Verificar rama main existe
if [ "$MAIN_EXISTS" != "true" ]; then
  echo "❌ CRITICAL: Main branch doesn't exist"
  echo "   Trunk-based development requires a trunk (main) branch"
  echo "   Fix: Create main branch as your trunk"
  ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

# 2. Verificar workflows críticos
if [ ${#WORKFLOWS_MISSING[@]} -gt 0 ]; then
  CRITICAL_MISSING=false
  for workflow in "${WORKFLOWS_MISSING[@]}"; do
    if [ "$workflow" == "trunk-ci.yml" ]; then
      CRITICAL_MISSING=true
      break
    fi
  done
  
  if [ "$CRITICAL_MISSING" == "true" ]; then
    echo "❌ CRITICAL: trunk-ci.yml workflow not found"
    echo "   This is the main CI/CD pipeline for trunk-based development"
    echo "   Fix: Create .github/workflows/trunk-ci.yml"
    echo "   See: docs/TrunkBasedShortLivedBranches.md for complete workflow template"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
  fi
  
  if [[ " ${WORKFLOWS_MISSING[@]} " =~ " fast-automerge.yml " ]]; then
    echo "⚠️  WARNING: fast-automerge.yml workflow not found"
    echo "   Recommended for automatic PR merging and branch age checks"
    echo "   Fix: Create .github/workflows/fast-automerge.yml"
    WARNINGS=$((WARNINGS + 1))
  fi
fi

# 3. Verificar permisos de Actions
if [ "$CAN_APPROVE_AVAILABLE" == "false" ]; then
  echo "ℹ️  INFO: Cannot verify PR approval permissions via GitHub API"
  echo "   This is normal for some repository types"
  echo "   Please manually verify in GitHub Settings → Actions → General:"
  echo "   1. Workflow permissions: 'Read and write permissions'"
  echo "   2. Check: '☑ Allow GitHub Actions to create and approve pull requests'"
elif [ "$CAN_APPROVE" == "false" ]; then
  echo "❌ CRITICAL: Actions cannot create and approve pull requests"
  echo "   Fix: Settings → Actions → General → Workflow permissions:"
  echo "   ✓ Read and write permissions"
  echo "   ✓ Allow GitHub Actions to create and approve pull requests"
  ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

# 4. Verificar Actions habilitado
if [ "$ACTIONS_ENABLED" != "true" ]; then
  echo "❌ CRITICAL: GitHub Actions is disabled"
  echo "   Trunk-based development relies heavily on CI/CD automation"
  echo "   Fix: Settings → Actions → General:"
  echo "   ✓ Enable GitHub Actions for this repository"
  ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

# 5. Verificar auto-merge habilitado
if [ "$AUTO_MERGE" != "true" ]; then
  echo "❌ CRITICAL: Auto-merge is not enabled in repository settings"
  echo "   Fix: Settings → General → Pull Requests:"
  echo "   ✓ Allow auto-merge"
  echo "   This enables fast integration of feature branches"
  ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

# 6. Verificar al menos un método de merge habilitado
if [ "$ALLOW_MERGE_COMMIT" != "true" ] && [ "$ALLOW_SQUASH_MERGE" != "true" ] && [ "$ALLOW_REBASE_MERGE" != "true" ]; then
  echo "❌ CRITICAL: No merge method is enabled"
  echo "   Fix: Settings → General → Pull Requests:"
  echo "   Recommended for trunk-based: Enable 'Squash merging' (keeps clean history)"
  ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

# 7. Verificar auto-delete de branches (DEBE estar activado para trunk-based)
if [ "$DELETE_BRANCH" != "true" ]; then
  echo "⚠️  WARNING: Auto-delete head branches is disabled"
  echo "   Recommendation: Settings → General → Pull Requests:"
  echo "   ✓ CHECK 'Automatically delete head branches'"
  echo "   Trunk-based development creates many short-lived branches - auto-cleanup is recommended"
  WARNINGS=$((WARNINGS + 1))
fi

# 8. Verificar branch protection en main
if [ "$MAIN_EXISTS" == "true" ]; then
  if [ "$REQUIRE_PR" != "true" ]; then
    echo "❌ CRITICAL: Main branch doesn't require pull requests"
    echo "   Even in trunk-based, all changes should go through PRs for CI validation"
    echo "   Fix: Settings → Branches → Add rule for 'main':"
    echo "   ✓ Require a pull request before merging"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
  fi
  
  # Verificar approvals (para trunk-based debería ser 0 o 1, no más)
  if [ "$APPROVALS" -gt 1 ]; then
    echo "⚠️  WARNING: Main requires $APPROVALS approvals - consider reducing for faster flow"
    echo "   Trunk-based development optimizes for speed: 0-1 approvals recommended"
    echo "   Rely on robust CI instead of multiple human approvals"
    echo "   Fix: Settings → Branches → main → Require approvals: 0 or 1"
    WARNINGS=$((WARNINGS + 1))
  fi
  
  # Verificar status checks
  if [ "$REQUIRE_CHECKS" != "true" ]; then
    echo "❌ CRITICAL: Main branch doesn't require status checks"
    echo "   Trunk-based relies on STRONG CI to replace human reviews"
    echo "   Fix: Settings → Branches → main:"
    echo "   ✓ Require status checks to pass before merging"
    echo "   Add checks: lint, test, build, integration-test, coverage-check"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
  elif [ "$REQUIRED_CHECKS" -lt 3 ]; then
    echo "⚠️  WARNING: Only $REQUIRED_CHECKS required status check(s) configured"
    echo "   Trunk-based development needs robust CI validation"
    echo "   Recommended checks: lint, test, build, integration-test, coverage-check"
    WARNINGS=$((WARNINGS + 1))
  fi
  
  # Verificar strict checks (up-to-date)
  if [ "$STRICT_CHECKS" != "true" ]; then
    echo "❌ CRITICAL: Branches not required to be up-to-date before merging"
    echo "   This can cause integration issues in trunk-based development"
    echo "   Fix: Settings → Branches → main:"
    echo "   ✓ Require branches to be up to date before merging"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
  fi
  
  # Verificar linear history (recomendado para trunk-based)
  if [ "$LINEAR_HISTORY" != "true" ]; then
    echo "⚠️  WARNING: Linear history not enforced"
    echo "   Recommendation: Settings → Branches → main:"
    echo "   ✓ Require linear history"
    echo "   This keeps the trunk clean and readable"
    WARNINGS=$((WARNINGS + 1))
  fi
  
  # Verificar que force push está deshabilitado
  if [ "$ALLOW_FORCE_PUSH" == "true" ]; then
    echo "❌ CRITICAL: Force pushes are allowed on main"
    echo "   The trunk should never be force-pushed"
    echo "   Fix: Settings → Branches → main:"
    echo "   Set 'Allow force pushes' to: Nobody"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
  fi
  
  # Verificar conversation resolution
  if [ "$CONVERSATION_RESOLUTION" != "true" ]; then
    echo "⚠️  WARNING: Conversation resolution not required"
    echo "   Recommendation: Settings → Branches → main:"
    echo "   ✓ Require conversation resolution before merging"
    WARNINGS=$((WARNINGS + 1))
  fi
fi

# 9. Verificar permisos de workflow
if [ "$WORKFLOW_PERMS_AVAILABLE" == "false" ]; then
  echo "ℹ️  INFO: Cannot determine default workflow permissions from GitHub API"
  echo "   Please verify manually: Settings → Actions → General → Workflow permissions"
  echo "   Should be set to: 'Read and write permissions'"
elif [ "$DEFAULT_WORKFLOW_PERMS" == "read" ]; then
  echo "⚠️  WARNING: Default workflow permissions is 'read'"
  echo "   Recommendation: Settings → Actions → General → Workflow permissions:"
  echo "   ✓ Select 'Read and write permissions'"
  WARNINGS=$((WARNINGS + 1))
fi

# 10. Verificar configuración óptima de merge para trunk-based
if [ "$ALLOW_SQUASH_MERGE" != "true" ]; then
  echo "⚠️  WARNING: Squash merge is not enabled"
  echo "   Recommendation for trunk-based: Enable squash merging"
  echo "   Fix: Settings → General → Pull Requests:"
  echo "   ✓ Allow squash merging"
  echo "   This keeps the trunk history clean with one commit per feature"
  WARNINGS=$((WARNINGS + 1))
fi

echo ""
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║              Trunk-Based Best Practices Check             ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

BEST_PRACTICES_ISSUES=0

# Check 1: Fast CI (no podemos verificar sin ejecutar, solo informar)
echo "🏃 CI Performance:"
echo "   ℹ️  Trunk-based requires fast CI (< 5 minutes total)"
echo "   ✓ Verify your CI completes in under 5 minutes"
echo "   ✓ Use parallelization, caching, and optimized test suites"
echo ""

# Check 2: Branch lifetime policies
echo "⏱️  Branch Lifetime:"
if [ -f ".github/workflows/stale-branches.yml" ]; then
  echo "   ✅ Stale branch detection configured"
else
  echo "   ⚠️  No stale branch detection configured"
  echo "   Recommendation: Add stale-branches.yml workflow to alert on branches > 2 days old"
  BEST_PRACTICES_ISSUES=$((BEST_PRACTICES_ISSUES + 1))
fi
echo "   Policy: Feature branches max 2 days, Fix branches max 1 day"
echo ""

# Check 3: Small PR size
echo "📏 PR Size:"
echo "   ℹ️  Recommended: PRs should be < 200 lines of code"
echo "   ✓ Consider adding a PR size labeler or check"
echo ""

# Check 4: Deployment frequency
echo "🚀 Deployment:"
echo "   ℹ️  Trunk-based aims for multiple deploys per day"
echo "   ✓ Ensure auto-deployment to staging is configured"
echo "   ✓ Production deployment should have minimal manual gates"
echo ""

# Summary
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║                      Summary                               ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

if [ $ISSUES_FOUND -eq 0 ] && [ $WARNINGS -eq 0 ] && [ $BEST_PRACTICES_ISSUES -eq 0 ]; then
  echo "✅ Excellent! All configurations are optimal for Trunk-Based Development!"
  echo ""
  echo "🚀 You're ready for high-velocity development!"
  echo ""
  echo "Next steps:"
  echo "   1. Create a feature branch: git checkout -b feature/TICKET-123-description"
  echo "   2. Make small, incremental changes"
  echo "   3. Push and create PR - auto-merge will handle the rest"
  echo "   4. Keep branches alive < 2 days, integrate frequently"
elif [ $ISSUES_FOUND -eq 0 ]; then
  echo "✅ Critical configurations are correct!"
  if [ $WARNINGS -gt 0 ]; then
    echo "⚠️  Found $WARNINGS warning(s) - consider addressing for optimal trunk-based workflow"
  fi
  if [ $BEST_PRACTICES_ISSUES -gt 0 ]; then
    echo "💡 Found $BEST_PRACTICES_ISSUES best practice suggestion(s)"
  fi
else
  echo "❌ Found $ISSUES_FOUND critical issue(s) that will prevent trunk-based development"
  if [ $WARNINGS -gt 0 ]; then
    echo "⚠️  Also found $WARNINGS warning(s)"
  fi
  if [ $BEST_PRACTICES_ISSUES -gt 0 ]; then
    echo "💡 Also found $BEST_PRACTICES_ISSUES best practice suggestion(s)"
  fi
  echo ""
  echo "📚 See documentation for detailed setup:"
  echo "   - docs/TrunkBasedShortLivedBranches.md"
  echo "   - AutoMergeTrunkBasedShortLivedBranches/README.md"
fi

echo ""
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║                  Quick Reference                           ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""
echo "📖 Trunk-Based Development Flow:"
echo "   main (trunk) ← feature/* branches (max 2 days)"
echo ""
echo "🔧 Key Principles:"
echo "   ✓ Always deployable main branch"
echo "   ✓ Short-lived feature branches (< 2 days)"
echo "   ✓ Minimal PR approvals (0-1), strong CI instead"
echo "   ✓ Fast CI pipeline (< 5 minutes)"
echo "   ✓ Small PRs (< 200 lines)"
echo "   ✓ High deployment frequency"
echo ""
echo "📝 Branch Naming:"
echo "   feature/<ticket>-description  (max 2 days)"
echo "   fix/<ticket>-description      (max 1 day)"
echo "   hotfix/<description>          (max 4 hours)"
echo ""
echo "🛠️ Useful scripts:"
echo "   ./scripts/check_repo_config.sh       - Run this health check"
echo "   ./scripts/create-quick-branch.sh     - Create a feature branch (if available)"
echo "   ./scripts/check-trunk-health.sh      - Check trunk stability (if available)"
echo ""
