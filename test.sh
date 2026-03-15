#!/bin/bash
#
# test.sh — Comprehensive test suite for dotfiles
#
# Tests:
#   1. Shell syntax       — bash -n on all shell files
#   2. Shellcheck         — lint all shell scripts
#   3. YAML validation    — validate k8s manifests
#   4. Secrets scan       — detect leaked credentials
#   5. Permissions check  — bin/ scripts must be executable
#   6. Symlink targets    — dotfiles exist and are valid
#   7. Python version     — no bare 'python' calls
#   8. Path hygiene       — flag hardcoded user-specific paths
#   9. Docker Compose     — validate compose file, .extra vars, service parity
#
# Usage:
#   ./test.sh           # run all tests
#   ./test.sh shell     # run only shell tests (syntax + shellcheck)
#   ./test.sh yaml      # run only yaml tests
#   ./test.sh secrets   # run only secrets scan
#   ./test.sh docker    # run only docker compose tests
#   ./test.sh quick     # syntax + secrets only (no shellcheck needed)
#
set -o pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

ERRORS=()
WARNINGS=()
PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0
SKIP_COUNT=0

pass() {
  ((PASS_COUNT++))
  echo -e "  ${GREEN}✓${NC} $1"
}

fail() {
  ((FAIL_COUNT++))
  ERRORS+=("$1")
  echo -e "  ${RED}✗${NC} $1"
}

warn() {
  ((WARN_COUNT++))
  WARNINGS+=("$1")
  echo -e "  ${YELLOW}⚠${NC} $1"
}

skip() {
  ((SKIP_COUNT++))
  echo -e "  ${BLUE}⊘${NC} $1 (skipped)"
}

header() {
  echo ""
  echo -e "${BLUE}━━━ $1 ━━━${NC}"
}

# ─── Test 1: Shell Syntax ─────────────────────────────────────────────────
test_syntax() {
  header "Shell Syntax (bash -n)"

  while IFS= read -r -d '' f; do
    if file "$f" | grep --quiet shell; then
      if bash -n "$f" 2>/dev/null; then
        pass "$f"
      else
        fail "$f — syntax error"
      fi
    fi
  done < <(find . -type f \
    -not -iwholename '*.git*' \
    -not -iwholename '*.idea*' \
    -not -name "*.yml" \
    -not -name "*.yaml" \
    -not -name "*.md" \
    -not -name "*.conf" \
    -not -name "*.sql" \
    -not -name "LICENSE" \
    -not -name "*.py" \
    -print0 | sort -z)
}

# ─── Test 2: Shellcheck ──────────────────────────────────────────────────
test_shellcheck() {
  header "Shellcheck Lint"

  if ! command -v shellcheck &>/dev/null; then
    skip "shellcheck not installed"
    return 0
  fi

  while IFS= read -r -d '' f; do
    if file "$f" | grep --quiet shell; then
      if shellcheck -S warning "$f" >/dev/null 2>&1; then
        pass "$f"
      else
        fail "$f — shellcheck errors"
        shellcheck -S warning "$f" 2>&1 | head -20 | sed 's/^/    /'
      fi
    fi
  done < <(find . -type f \
    -not -iwholename '*.git*' \
    -not -iwholename '*.idea*' \
    -not -name "*.yml" \
    -not -name "*.yaml" \
    -not -name "*.md" \
    -not -name "*.conf" \
    -not -name "*.sql" \
    -not -name "LICENSE" \
    -not -name "*.py" \
    -print0 | sort -z)
}

# ─── Test 3: YAML Validation ─────────────────────────────────────────────
test_yaml() {
  header "YAML / Kubernetes Manifests"

  local k8s_dir="./media/k8s"
  if [[ ! -d "$k8s_dir" ]]; then
    skip "No k8s directory found"
    return 0
  fi

  # YAML syntax check
  if command -v python3 &>/dev/null && python3 -c "import yaml" 2>/dev/null; then
    # Full validation with PyYAML
    while IFS= read -r -d '' f; do
      if python3 -c "
import yaml, sys
try:
    with open('$f') as fh:
        list(yaml.safe_load_all(fh))
except Exception as e:
    print(str(e), file=sys.stderr)
    sys.exit(1)
" 2>/dev/null; then
        pass "$f — valid YAML"
      else
        fail "$f — invalid YAML"
      fi
    done < <(find "$k8s_dir" \( -name "*.yaml" -o -name "*.yml" \) -print0 | sort -z)
  else
    skip "PyYAML not installed (pip3 install pyyaml)"
  fi

  # kubectl dry-run if available
  if command -v kubectl &>/dev/null; then
    # Check if kubectl can reach a cluster before validating manifests
    if ! kubectl cluster-info --request-timeout=5s >/dev/null 2>&1; then
      skip "kubectl installed but no reachable cluster (dry-run requires a running cluster)"
    elif kubectl apply --dry-run=client -f "$k8s_dir/" >/dev/null 2>&1; then
      pass "kubectl dry-run — all manifests valid"
    else
      fail "kubectl dry-run — manifests have errors"
      kubectl apply --dry-run=client -f "$k8s_dir/" 2>&1 | grep -i error | head -5 | sed 's/^/    /'
    fi
  else
    skip "kubectl not available for manifest validation"
  fi
}

# ─── Test 4: Secrets Scan ────────────────────────────────────────────────
test_secrets() {
  header "Secrets & Credential Scan"

  local secrets_found=0

  # Patterns that indicate leaked secrets
  local -a patterns=(
    'AKIA[0-9A-Z]{16}'                   # AWS Access Key
    'password\s*=\s*["\x27][^"\x27]+'     # password = "..."
    'secret_key\s*=\s*["\x27][^"\x27]+'   # secret_key = "..."
    'claim-[a-zA-Z0-9_-]{10,}'            # Plex claim tokens
    'ghp_[a-zA-Z0-9]{36}'                 # GitHub personal access tokens
    'sk-[a-zA-Z0-9]{32,}'                 # OpenAI / Stripe secret keys
    'xox[bporas]-[a-zA-Z0-9-]+'           # Slack tokens
  )

  for pattern in "${patterns[@]}"; do
    local matches
    matches=$(grep -rn -E "$pattern" \
      --include="*.sh" \
      --include="*.bash" \
      --include="*.yml" \
      --include="*.yaml" \
      --include="*.conf" \
      --include="*.config" \
      . 2>/dev/null \
      | grep -v '.git/' \
      | grep -v '.extra.example' \
      | grep -v 'test.sh' \
      | grep -v 'SECURITY.md' \
      | grep -v 'README.md' \
      || true)

    if [[ -n "$matches" ]]; then
      secrets_found=1
      fail "Potential secret found (pattern: ${pattern:0:20}...)"
      echo "$matches" | head -3 | sed 's/^/    /'
    fi
  done

  # Check that .extra is gitignored
  if grep -q "^\.extra$" .gitignore 2>/dev/null; then
    pass ".extra is gitignored"
  else
    fail ".extra is NOT gitignored — secrets may be committed!"
  fi

  # Ensure .env is gitignored (compose secrets)
  if grep -q '^\.env$' ./gitignore 2>/dev/null; then
    pass ".env is gitignored"
  else
    fail ".env is NOT gitignored — compose secrets may be committed!"
  fi

  # Flag any committed .env file (legacy — all config is in .extra now)
  if [[ -f ./media/.env ]]; then
    warn "media/.env exists — make sure it is NOT tracked by git"
  fi

  # Check that .aws/credentials is gitignored
  if grep -q "credentials" .gitignore 2>/dev/null; then
    pass ".aws/credentials is gitignored"
  else
    warn ".aws/credentials not explicitly gitignored"
  fi

  # Check .gitconfig for plaintext credential storage
  if grep -q "helper = store" .gitconfig 2>/dev/null; then
    fail ".gitconfig uses 'credential.helper = store' (plaintext passwords!)"
  else
    pass ".gitconfig credential helper is safe"
  fi

  if [[ $secrets_found -eq 0 ]]; then
    pass "No leaked secrets detected in tracked files"
  fi
}

# ─── Test 5: Permissions Check ───────────────────────────────────────────
test_permissions() {
  header "File Permissions"

  # All files in bin/ should be executable
  while IFS= read -r -d '' f; do
    if [[ -x "$f" ]]; then
      pass "$f is executable"
    else
      fail "$f is NOT executable"
    fi
  done < <(find ./bin -type f -not -name ".*.swp" -print0 | sort -z)

  # test.sh itself should be executable
  if [[ -x "./test.sh" ]]; then
    pass "test.sh is executable"
  else
    warn "test.sh is not executable"
  fi
}

# ─── Test 6: Dotfile Symlink Targets ─────────────────────────────────────
test_dotfiles() {
  header "Dotfile Integrity"

  # Check that expected dotfiles exist
  local -a expected_dotfiles=(
    .aliases
    .bash_profile
    .bash_prompt
    .bashrc
    .dockerfunc
    .exports
    .functions
    .gitconfig
    .inputrc
    .path
    .tmux.conf
  )

  for df in "${expected_dotfiles[@]}"; do
    if [[ -f "./${df}" ]]; then
      pass "${df} exists"
    else
      fail "${df} is missing!"
    fi
  done

  # Verify .bashrc sources the right files
  local -a sourced_files=(bash_prompt aliases functions path dockerfunc exports)
  for sf in "${sourced_files[@]}"; do
    if grep -q "$sf" .bashrc 2>/dev/null; then
      pass ".bashrc sources ${sf}"
    else
      warn ".bashrc does not source ${sf}"
    fi
  done
}

# ─── Test 7: Python Version Check ────────────────────────────────────────
test_python_version() {
  header "Python Version References"

  # Find bare 'python' calls (should be python3)
  local py2_refs
  py2_refs=$(grep -rn '\bpython\b' \
    --include="*.sh" \
    --include="*.bash" \
    . 2>/dev/null \
    | grep -v '.git/' \
    | grep -v 'python3' \
    | grep -v 'python@' \
    | grep -v '#.*python' \
    | grep -v 'test.sh' \
    || true)

  if [[ -z "$py2_refs" ]]; then
    pass "No bare 'python' references (all use python3)"
  else
    warn "Found bare 'python' references (should be python3):"
    echo "$py2_refs" | head -5 | sed 's/^/    /'
  fi

  # Check aliases and functions too
  local py2_aliases
  py2_aliases=$(grep -n '\bpython\b' .aliases .functions .exports 2>/dev/null \
    | grep -v 'python3' \
    | grep -v 'python@' \
    | grep -v '#.*python' \
    || true)

  if [[ -z "$py2_aliases" ]]; then
    pass "No Python 2 references in shell config"
  else
    warn "Python 2 references in shell config:"
    echo "$py2_aliases" | head -5 | sed 's/^/    /'
  fi
}

# ─── Test 8: Path Hygiene ────────────────────────────────────────────────
test_paths() {
  header "Path Hygiene"

  # Check for hardcoded home directories in shell scripts
  local hardcoded
  hardcoded=$(grep -rn '/home/[a-z]' \
    --include="*.sh" \
    --include="*.bash" \
    . 2>/dev/null \
    | grep -v '.git/' \
    | grep -v 'test.sh' \
    || true)

  if [[ -z "$hardcoded" ]]; then
    pass "No hardcoded /home/<user> paths in shell scripts"
  else
    warn "Hardcoded user paths found in shell scripts:"
    echo "$hardcoded" | head -5 | sed 's/^/    /'
  fi

  # K8s manifests should use ${VAR} templates, NOT hardcoded /home/ paths
  if [[ -d media/k8s ]]; then
    local k8s_hardcoded
    k8s_hardcoded=$(grep -rn '/home/[a-z]' media/k8s/ 2>/dev/null || true)
    if [[ -z "$k8s_hardcoded" ]]; then
      pass "K8s manifests use templated paths (no hardcoded /home/)"
    else
      local count
      count=$(echo "$k8s_hardcoded" | wc -l | tr -d ' ')
      fail "K8s manifests have ${count} hardcoded /home/ paths — should use \${VAR} templates"
      echo "$k8s_hardcoded" | head -3 | sed 's/^/    /'
    fi

    # Verify templates reference expected variables
    local -a expected_vars=(CONFIG_PATH DOWNLOADS_PATH MEDIA_PATH PLEX_CONFIG_PATH PLEX_TRANSCODE_PATH)
    for var in "${expected_vars[@]}"; do
      if grep -rq "\${${var}}" media/k8s/ 2>/dev/null; then
        pass "K8s manifests use \${${var}}"
      else
        warn "K8s manifests do not reference \${${var}}"
      fi
    done
  fi

  # Verify required media stack vars are defined in .extra
  if [[ -f .extra ]]; then
    local -a required_exports=(CONFIG_PATH DOWNLOADS_PATH MEDIA_PATH PLEX_CONFIG_PATH PLEX_TRANSCODE_PATH)
    for var in "${required_exports[@]}"; do
      if grep -q "export ${var}=" .extra 2>/dev/null; then
        pass "${var} is set in .extra"
      else
        warn "${var} not found in .extra — media stack will fail to deploy"
      fi
    done
  fi

  # Check for legacy GOPATH references
  if grep -rq 'GOPATH' .exports 2>/dev/null; then
    warn "GOPATH referenced in .exports — consider using Go modules instead"
  else
    pass "No legacy GOPATH references in .exports"
  fi
}

# ─── Test 9: Docker Compose ───────────────────────────────────────────────
test_docker_compose() {
  header "Docker Compose"

  local compose_file="./media/docker-compose.yaml"
  local extra_file="./.extra"

  # ── File presence ──────────────────────────────────────────────────────
  if [[ -f "$compose_file" ]]; then
    pass "docker-compose.yaml exists"
  else
    fail "docker-compose.yaml is missing"
    return 0
  fi

  # ── YAML syntax ───────────────────────────────────────────────────────
  if command -v python3 &>/dev/null && python3 -c "import yaml" 2>/dev/null; then
    if python3 -c "
import yaml, sys
try:
    with open('$compose_file') as fh:
        list(yaml.safe_load_all(fh))
except Exception as e:
    print(str(e), file=sys.stderr)
    sys.exit(1)
" 2>/dev/null; then
      pass "$compose_file — valid YAML"
    else
      fail "$compose_file — invalid YAML"
    fi
  else
    skip "PyYAML not installed (pip3 install pyyaml)"
  fi

  # ── docker compose config dry-run ─────────────────────────────────────
  if command -v docker &>/dev/null && docker compose version &>/dev/null; then
    if docker compose -f "$compose_file" config --quiet 2>/dev/null; then
      pass "docker compose config — valid"
    else
      fail "docker compose config — compose file has errors"
      docker compose -f "$compose_file" config 2>&1 | head -5 | sed 's/^/    /'
    fi
  else
    skip "docker compose not available for config validation"
  fi

  # ── Required service definitions ──────────────────────────────────────
  local -a expected_services=(plex transmission sonarr radarr prowlarr flaresolverr bazarr overseerr)
  for svc in "${expected_services[@]}"; do
    if grep -q "container_name: ${svc}" "$compose_file" 2>/dev/null; then
      pass "service '${svc}' defined in compose"
    else
      fail "service '${svc}' missing from compose"
    fi
  done

  # ── Every service should have restart policy ──────────────────────────
  local svc_count restart_count
  svc_count=$(grep -c 'container_name:' "$compose_file" 2>/dev/null || echo 0)
  restart_count=$(grep -c 'restart:' "$compose_file" 2>/dev/null || echo 0)
  if [[ "$svc_count" -eq "$restart_count" ]]; then
    pass "All ${svc_count} services have a restart policy"
  else
    fail "${restart_count}/${svc_count} services have a restart policy"
  fi

  # ── Service parity: compose vs k8s ────────────────────────────────────
  if [[ -d "./media/k8s" ]]; then
    local -a k8s_apps=()
    while IFS= read -r app; do
      [[ -n "$app" ]] && k8s_apps+=("$app")
    done < <(grep -rh 'app:' media/k8s/*.yaml 2>/dev/null \
      | awk '{print $NF}' | sort -u)

    local missing=0
    for app in "${k8s_apps[@]}"; do
      if ! grep -q "container_name: ${app}" "$compose_file" 2>/dev/null; then
        fail "K8s service '${app}' has no matching compose service"
        missing=1
      fi
    done
    if [[ $missing -eq 0 ]]; then
      pass "Compose and K8s define the same services"
    fi
  fi

  # ── .extra covers all compose variables ────────────────────────────────
  # Compose vars are set in ~/.extra (sourced by .bashrc), not a .env file.
  if [[ -f "$extra_file" ]]; then
    # Extract ${VAR_NAME:-...} or ${VAR_NAME} references from compose
    local -a compose_vars=()
    while IFS= read -r var; do
      [[ -n "$var" ]] && compose_vars+=("$var")
    done < <(grep -oE '\$\{[A-Z_]+' "$compose_file" \
      | sed 's/\${//' | sort -u)

    local env_missing=0
    for var in "${compose_vars[@]}"; do
      if grep -q "export ${var}=" "$extra_file" 2>/dev/null; then
        pass ".extra defines ${var}"
      else
        fail ".extra is missing 'export ${var}=' — compose will use defaults"
        env_missing=1
      fi
    done
    if [[ $env_missing -eq 0 && ${#compose_vars[@]} -gt 0 ]]; then
      pass "All compose variables defined in .extra"
    fi
  fi

  # ── .env must be gitignored (safety net) ──────────────────────────────
  if grep -q '^\.env$' ./gitignore 2>/dev/null; then
    pass ".env is gitignored (secrets safe)"
  else
    fail ".env is NOT gitignored — secrets may be committed!"
  fi

  # ── No hardcoded /home/ or /Users/ paths in compose ───────────────────
  local compose_hardcoded
  compose_hardcoded=$(grep -n '/home/[a-z]\|/Users/[a-z]' "$compose_file" 2>/dev/null \
    | grep -v '#' || true)
  if [[ -z "$compose_hardcoded" ]]; then
    pass "docker-compose.yaml has no hardcoded user paths"
  else
    fail "docker-compose.yaml has hardcoded user paths:"
    echo "$compose_hardcoded" | head -3 | sed 's/^/    /'
  fi
}

# ─── Summary ─────────────────────────────────────────────────────────────
summary() {
  echo ""
  echo -e "${BLUE}━━━ Summary ━━━${NC}"
  echo -e "  ${GREEN}Passed:${NC}   ${PASS_COUNT}"
  echo -e "  ${RED}Failed:${NC}   ${FAIL_COUNT}"
  echo -e "  ${YELLOW}Warnings:${NC} ${WARN_COUNT}"
  echo -e "  ${BLUE}Skipped:${NC}  ${SKIP_COUNT}"
  echo ""

  if [ ${#ERRORS[@]} -gt 0 ]; then
    echo -e "${RED}Failed tests:${NC}"
    for err in "${ERRORS[@]}"; do
      echo -e "  ${RED}✗${NC} ${err}"
    done
    echo ""
  fi

  if [ ${#WARNINGS[@]} -gt 0 ]; then
    echo -e "${YELLOW}Warnings:${NC}"
    for w in "${WARNINGS[@]}"; do
      echo -e "  ${YELLOW}⚠${NC} ${w}"
    done
    echo ""
  fi

  if [ ${FAIL_COUNT} -eq 0 ]; then
    echo -e "${GREEN}All tests passed! 🎉${NC}"
    return 0
  else
    echo -e "${RED}${FAIL_COUNT} test(s) failed.${NC}"
    return 1
  fi
}

# ─── Main ────────────────────────────────────────────────────────────────
main() {
  local cmd="${1:-all}"

  echo -e "${BLUE}dotfiles test suite${NC}"
  echo -e "${BLUE}$(date)${NC}"

  case "$cmd" in
    shell)
      test_syntax
      test_shellcheck
      ;;
    yaml)
      test_yaml
      test_docker_compose
      ;;
    secrets)
      test_secrets
      ;;
    docker)
      test_docker_compose
      ;;
    quick)
      test_syntax
      test_secrets
      test_permissions
      test_dotfiles
      ;;
    all)
      test_syntax
      test_shellcheck
      test_yaml
      test_docker_compose
      test_secrets
      test_permissions
      test_dotfiles
      test_python_version
      test_paths
      ;;
    *)
      echo "Usage: $0 {all|shell|yaml|docker|secrets|quick}"
      echo ""
      echo "  all      Run all tests (default)"
      echo "  shell    Shell syntax + shellcheck only"
      echo "  yaml     YAML/k8s manifest validation only"
      echo "  docker   Docker Compose validation only"
      echo "  secrets  Credential leak scan only"
      echo "  quick    Syntax + secrets + permissions (no shellcheck)"
      exit 1
      ;;
  esac

  summary
}

main "$@"
