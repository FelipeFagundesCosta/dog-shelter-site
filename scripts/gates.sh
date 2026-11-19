#!/usr/bin/env bash
# gates.sh — portões de qualidade determinísticos (camada "harness engineering").
#
# Uso: gates.sh <repo> [pasta-de-saida]
#
# Detecta a stack e roda, nesta ordem, o que existir:
#   Node (package.json na raiz e em GATES_DIRS): install (se faltar node_modules),
#        lint, typecheck (script ou tsc --noEmit se houver tsconfig), test, build, e2e
#   Python (pyproject.toml): ruff check, ruff format --check, pyright/mypy, pytest
# Override por projeto: arquivo <repo>/.gates (um comando por linha, # comenta);
#   se existir, substitui a autodetecção.
#
# Saídas em <pasta-de-saida> (padrão: ./gates-out):
#   gates.log    saída completa de todos os comandos
#   gates.md     tabela gate | comando | resultado | duração
#   gates.status uma linha: PASS ou FAIL
# Código de saída: 0 se PASS, 1 se FAIL.
#
# Variáveis:
#   GATES_DIRS="frontend web"   subpastas Node extras a verificar (além da raiz)
#   GATES_SKIP="e2e build"      gates a pular (registrado como SKIP no relatório)
#   GATES_ALLOW_EMPTY=1         não falhar quando nenhum gate for detectado
#   GATES_TIMEOUT=900           timeout (s) por comando

set -uo pipefail

REPO="${1:-}"
OUT="${2:-./gates-out}"
[[ -n "${REPO}" && -d "${REPO}" ]] || { echo "Uso: $0 <repo> [pasta-de-saida]" >&2; exit 2; }
REPO="$(cd "${REPO}" && pwd)"
mkdir -p "${OUT}"
OUT="$(cd "${OUT}" && pwd)"
LOG="${OUT}/gates.log"
MD="${OUT}/gates.md"
STATUS="${OUT}/gates.status"
TIMEOUT="${GATES_TIMEOUT:-900}"
SKIP=" ${GATES_SKIP:-} "

: > "${LOG}"
{
  echo "# Gates de qualidade"
  echo
  echo "- Repo: \`${REPO}\`"
  echo "- Branch: \`$(git -C "${REPO}" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')\` (\`$(git -C "${REPO}" rev-parse --short HEAD 2>/dev/null || echo '?')\`)"
  echo "- Início: $(date '+%Y-%m-%d %H:%M:%S %Z')"
} > "${MD}"

FAILS=0
COUNT=0

export CI=1 FORCE_COLOR=0 NO_COLOR=1

# --- Toolchain Node -----------------------------------------------------------
# Os agentes (cursor-agent) rodam com o Node embutido do cursor-agent no PATH,
# que pode ser mais novo que o Node do sistema. Para os gates verem o mesmo
# ambiente: GATES_NODE_DIR explícito > Node do sistema se >= GATES_NODE_MIN >
# Node embutido do cursor-agent.
GATES_NODE_MIN="${GATES_NODE_MIN:-20}"
node_major() { "${1:-node}" -v 2>/dev/null | sed -E 's/^v([0-9]+).*/\1/'; }
NODE_NOTE=""
if [[ -n "${GATES_NODE_DIR:-}" ]]; then
  export PATH="${GATES_NODE_DIR}:${PATH}"; NODE_NOTE="GATES_NODE_DIR"
elif [[ "$(node_major node || echo 0)" -lt "${GATES_NODE_MIN}" ]] 2>/dev/null; then
  agent_bin="${WEBDEV_AGENT_BIN:-${HOME}/.local/bin/cursor-agent}"
  if [[ -x "${agent_bin}" ]]; then
    agent_dir="$(dirname "$(readlink -f "${agent_bin}")")"
    if [[ -x "${agent_dir}/node" && "$(node_major "${agent_dir}/node" || echo 0)" -ge "${GATES_NODE_MIN}" ]]; then
      export PATH="${agent_dir}:${PATH}"; NODE_NOTE="Node do sistema < ${GATES_NODE_MIN}; usando o Node embutido do cursor-agent (${agent_dir})"
    fi
  fi
fi
if command -v node >/dev/null 2>&1; then
  echo "- Node: \`$(node -v)\` em \`$(command -v node)\`${NODE_NOTE:+ (${NODE_NOTE})}; npm \`$(npm -v 2>/dev/null || echo '?')\`" >> "${MD}"
fi
{
  echo
  echo "| Gate | Diretório | Comando | Resultado | Duração |"
  echo "|---|---|---|---|---|"
} >> "${MD}"

run_gate() {
  # run_gate <nome> <dir> <comando...>
  local name="$1" dir="$2"; shift 2
  local cmd="$*"
  local rel="${dir#${REPO}}"; rel="${rel:-/}"; [[ "${rel}" == /* ]] || rel="/${rel}"
  if [[ "${SKIP}" == *" ${name} "* ]]; then
    echo "| ${name} | \`${rel}\` | \`${cmd}\` | SKIP (GATES_SKIP) | - |" >> "${MD}"
    return 0
  fi
  COUNT=$((COUNT + 1))
  local t0 t1 rc
  t0=$(date +%s)
  {
    echo
    echo "================================================================"
    echo "[gate] ${name}  dir=${rel}  cmd=${cmd}"
    echo "================================================================"
  } >> "${LOG}"
  ( cd "${dir}" && timeout "${TIMEOUT}" bash -c "${cmd}" ) >> "${LOG}" 2>&1 < /dev/null
  rc=$?
  t1=$(date +%s)
  local res="PASS"
  if [[ ${rc} -ne 0 ]]; then res="FAIL (rc=${rc})"; FAILS=$((FAILS + 1)); fi
  echo "[gate] ${name} -> ${res}" >> "${LOG}"
  echo "| ${name} | \`${rel}\` | \`${cmd}\` | ${res} | $((t1 - t0))s |" >> "${MD}"
  echo "[gate] ${name} (${rel}) -> ${res}"
}

has_script() { # has_script <dir> <nome>
  python3 - "$1/package.json" "$2" <<'PY'
import json, sys
try:
    d = json.load(open(sys.argv[1], encoding="utf-8"))
except Exception:
    sys.exit(1)
sys.exit(0 if sys.argv[2] in (d.get("scripts") or {}) else 1)
PY
}

node_gates() {
  local dir="$1" pm="npm" run="npm run" install=""
  if [[ -f "${dir}/pnpm-lock.yaml" ]]; then pm="pnpm"; run="pnpm run"; install="pnpm install --frozen-lockfile"
  elif [[ -f "${dir}/yarn.lock" ]]; then pm="yarn"; run="yarn run"; install="yarn install --frozen-lockfile"
  elif [[ -f "${dir}/bun.lockb" || -f "${dir}/bun.lock" ]]; then pm="bun"; run="bun run"; install="bun install --frozen-lockfile"
  elif [[ -f "${dir}/package-lock.json" ]]; then install="npm ci"
  else install="npm install --no-audit --no-fund"
  fi
  if [[ ! -d "${dir}/node_modules" ]]; then
    run_gate "install" "${dir}" "${install}"
  fi
  has_script "${dir}" lint && run_gate "lint" "${dir}" "${run} lint"
  if has_script "${dir}" typecheck; then run_gate "typecheck" "${dir}" "${run} typecheck"
  elif has_script "${dir}" type-check; then run_gate "typecheck" "${dir}" "${run} type-check"
  elif [[ -f "${dir}/tsconfig.json" ]]; then run_gate "typecheck" "${dir}" "npx --no-install tsc --noEmit"
  fi
  if has_script "${dir}" test:unit; then run_gate "test" "${dir}" "${run} test:unit"
  elif has_script "${dir}" test; then run_gate "test" "${dir}" "${run} test"
  fi
  has_script "${dir}" build && run_gate "build" "${dir}" "${run} build"
  if has_script "${dir}" test:e2e; then run_gate "e2e" "${dir}" "${run} test:e2e"
  elif has_script "${dir}" e2e; then run_gate "e2e" "${dir}" "${run} e2e"
  fi
  : "${pm}"
}

python_gates() {
  local dir="$1" pre=""
  if [[ -f "${dir}/uv.lock" ]] && command -v uv >/dev/null 2>&1; then
    run_gate "py-install" "${dir}" "uv sync --locked --all-extras"
    pre="uv run "
  fi
  if grep -q '\[tool.ruff' "${dir}/pyproject.toml" 2>/dev/null || [[ -f "${dir}/ruff.toml" ]]; then
    run_gate "py-lint" "${dir}" "${pre}ruff check ."
    run_gate "py-format" "${dir}" "${pre}ruff format --check ."
  fi
  if grep -q '\[tool.pyright' "${dir}/pyproject.toml" 2>/dev/null || [[ -f "${dir}/pyrightconfig.json" ]]; then
    run_gate "py-typecheck" "${dir}" "${pre}pyright"
  elif grep -q '\[tool.mypy' "${dir}/pyproject.toml" 2>/dev/null; then
    run_gate "py-typecheck" "${dir}" "${pre}mypy ."
  fi
  if [[ -d "${dir}/tests" ]] || grep -q '\[tool.pytest' "${dir}/pyproject.toml" 2>/dev/null; then
    run_gate "py-test" "${dir}" "${pre}pytest -q"
  fi
}

if [[ -f "${REPO}/.gates" ]]; then
  echo "[gates] usando override ${REPO}/.gates" | tee -a "${LOG}"
  i=0
  while IFS= read -r line || [[ -n "${line}" ]]; do
    line="${line%%#*}"; line="$(echo "${line}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [[ -z "${line}" ]] && continue
    i=$((i + 1))
    run_gate "custom-${i}" "${REPO}" "${line}"
  done < "${REPO}/.gates"
else
  dirs=("${REPO}")
  for d in ${GATES_DIRS:-}; do [[ -d "${REPO}/${d}" ]] && dirs+=("${REPO}/${d}"); done
  for d in "${dirs[@]}"; do
    [[ -f "${d}/package.json" ]] && node_gates "${d}"
    [[ -f "${d}/pyproject.toml" ]] && python_gates "${d}"
  done
fi

result="PASS"
if [[ ${COUNT} -eq 0 ]]; then
  if [[ "${GATES_ALLOW_EMPTY:-0}" == "1" ]]; then
    echo "| (nenhum) | - | nenhum gate detectado | SKIP (GATES_ALLOW_EMPTY=1) | - |" >> "${MD}"
  else
    echo "| (nenhum) | - | nenhum gate detectado (sem package.json/pyproject.toml/.gates) | FAIL | - |" >> "${MD}"
    result="FAIL"
  fi
fi
[[ ${FAILS} -gt 0 ]] && result="FAIL"
{
  echo
  echo "- Fim: $(date '+%Y-%m-%d %H:%M:%S %Z')"
  echo "- Gates executados: ${COUNT}; falhas: ${FAILS}"
  echo
  echo "GATES: ${result}"
} >> "${MD}"
echo "${result}" > "${STATUS}"
echo "[gates] resultado=${result} (executados=${COUNT}, falhas=${FAILS}) relatório=${MD}"
[[ "${result}" == "PASS" ]]
