#!/usr/bin/env bash
# 세션 시작 훅 — 알파웍스 CLI(alphaworks)가 없으면 공개 npm으로 깔고, 하루 한 번 새 판으로 올림 (2026-11-19 공개 npm — #690, planning/55-CLI-단일바이너리 "공개 npm으로 바꿈")
# hooks.json이 async로 등록 — 세션을 막지 않고 뒤에서 돎. 바뀐 것 · 사람이 할 것이 있을 때만 마지막 줄 JSON(additionalContext)으로 에이전트에게 한 줄 알림
# CLI가 혼자 바꾸지 않음 — 이 훅이 `npm install -g`(처음) · `alphaworks self-update`(그 뒤)를 부르는 것뿐. 끄기: CORP_PLATFORM_NO_AUTO_UPDATE=1 또는 ~/.alphaworks/no-auto-update 파일(옛 자리 ~/.corp-platform/no-auto-update도)
# 사본: Claude Code용(plugins/alphaworks)과 Codex용(plugins/alphaworks-codex)이 글자 그대로 같음 — scripts/test/plugins.test.ts가 견줌
# NOTE: 비밀값 · 토큰 없음. 받는 곳은 공개 npm 레지스트리 하나. Node(npm)가 없으면 깔지 않고 알리기만 — Node 설치는 사람 승인("시작해줘" 온보딩)
# NOTE: 옛 단일 실행 파일(~/.alphaworks/bin · ~/.corp-platform/bin)은 지우지 않음 — npm 판을 깐 뒤 지우라고 알림(사람 PC의 폴더라 에이전트 · 사람이 지움)
host=${1:-claude}
[ -n "${CORP_PLATFORM_NO_AUTO_UPDATE:-}" ] && exit 0
[ -f "$HOME/.alphaworks/no-auto-update" ] && exit 0
[ -f "$HOME/.corp-platform/no-auto-update" ] && exit 0

PACKAGE='@alphabro/alphaworks-cli'
INSTALL="npm install -g $PACKAGE"
# 캐시 · 잠금 · 시간 표시 — 옛 자리(~/.corp-platform)에 실행 파일을 깐 PC는 옛 훅과 같은 표시를 봐 하루 두 번 올리지 않게 그 자리
LEGACY_DIR="$HOME/.corp-platform"
DIR="$HOME/.alphaworks"
OLD_DIRS=()
for d in "$HOME/.alphaworks/bin" "$LEGACY_DIR/bin"; do
  for f in alphaworks alphaworks.exe corp-platform.exe corp-platform; do # 옛 이름 실행 파일도
    [ -e "$d/$f" ] && { OLD_DIRS+=("$d"); break; }
  done
done
for f in alphaworks alphaworks.exe corp-platform.exe corp-platform; do
  [ -e "$LEGACY_DIR/bin/$f" ] && { DIR=$LEGACY_DIR; break; }
done
CACHE="$DIR/cache"
mkdir -p "$CACHE" 2>/dev/null || exit 0
LOG="$CACHE/plugin-update.log"
STAMP="$CACHE/last-plugin-update"

log() {
  printf '%s host=%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$host" "$*" >>"$LOG" 2>/dev/null
  if [ "$(wc -l <"$LOG" 2>/dev/null | tr -d ' ')" -gt 200 ] 2>/dev/null; then tail -n 200 "$LOG" >"$LOG.tmp" 2>/dev/null && mv "$LOG.tmp" "$LOG" 2>/dev/null; fi
}
say() { # 에이전트에게 한 줄 (다음 턴에 전달됨)
  local text=${1//\"/\'}
  text=${text//\\/\/}
  text=$(printf '%s' "$text" | tr -d '\000-\037')
  printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' "$text"
}

# 하루 한 번 — 동시 세션은 mkdir 잠금(30분 지난 잠금은 회수)
[ -f "$STAMP" ] && [ -n "$(find "$STAMP" -mmin -1440 2>/dev/null)" ] && exit 0
LOCK="$CACHE/.plugin-update.lock"
if ! mkdir "$LOCK" 2>/dev/null; then
  [ -n "$(find "$LOCK" -maxdepth 0 -mmin +30 2>/dev/null)" ] || exit 0
  rm -rf "$LOCK" 2>/dev/null
  mkdir "$LOCK" 2>/dev/null || exit 0
fi
trap 'rm -rf "$LOCK" 2>/dev/null' EXIT

OLD_NOTE=''
[ ${#OLD_DIRS[@]} -gt 0 ] && OLD_NOTE=" 옛 실행 파일 폴더가 남아 있어요(${OLD_DIRS[*]}) — npm 판으로 옮겼으니 사람에게 묻고 지우세요(셸 시작 파일의 그 PATH 줄도). alphaworks setup이 지울 줄을 알려 줘요."

# npm으로 깐 CLI — 전역 폴더(npm prefix -g)에서 찾음. 셸 PATH에 npm 전역 bin이 없을 때(nvm 등)도 찾게. npm이 없으면 PATH의 alphaworks(옛 실행 파일 폴더 밖)
NPM=$(command -v npm 2>/dev/null || true)
find_cli() {
  local p c
  if [ -n "$NPM" ]; then
    p=$("$NPM" prefix -g 2>/dev/null) || p=''
    for c in "$p/bin/alphaworks" "$p/alphaworks"; do
      [ -n "$p" ] && [ -x "$c" ] && { printf '%s' "$c"; return 0; }
    done
  fi
  c=$(command -v alphaworks 2>/dev/null || true)
  case "$c" in "" | "$HOME/.alphaworks/bin/"* | "$LEGACY_DIR/bin/"*) return 1 ;; esac
  printf '%s' "$c"
}
CLI=$(find_cli || true)

# 설치 — 성공은 설치 뒤 alphaworks --version이 버전을 낼 때만. 실패면 시간 표시를 남기지 않아 다음 세션 시작에 다시 시도
install_cli() {
  local out code=0 v
  out=$("$NPM" install -g --no-audit --no-fund "$PACKAGE" 2>&1) || code=$?
  if [ "$code" != 0 ]; then
    case "$out" in
      *EACCES* | *EPERM*) FAIL_WHY="npm 전역 폴더에 쓸 권한이 없어요(EACCES). sudo를 쓰지 말고 사람에게 알려 npm config set prefix ~/.npm-global 뒤 ~/.npm-global/bin을 PATH에 넣고 다시 깔아요"; FAIL_CODE=permission ;;
      *SELF_SIGNED_CERT* | *UNABLE_TO_GET_ISSUER* | *UNABLE_TO_VERIFY_LEAF*) FAIL_WHY="보안 연결(TLS)을 확인하지 못했어요. 회사 보안 프로그램이 registry.npmjs.org 연결을 가로챘을 수 있어요"; FAIL_CODE=tls_intercepted ;;
      *ETIMEDOUT* | *ECONNRESET* | *ENOTFOUND* | *EAI_AGAIN* | *ECONNREFUSED*) FAIL_WHY="npm 레지스트리(registry.npmjs.org)에 닿지 못했어요. 회사망 · VPN · 프록시가 막았을 수 있어요"; FAIL_CODE=network_blocked ;;
      *) FAIL_WHY="npm 설치가 실패했어요 ($(printf '%s\n' "$out" | grep -v '^\s*$' | tail -n 1))"; FAIL_CODE=npm_failed ;;
    esac
    return 1
  fi
  NEW_CLI=$(find_cli || true)
  v=$([ -n "$NEW_CLI" ] && "$NEW_CLI" --version 2>/dev/null || true)
  if ! printf '%s' "$v" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+'; then
    FAIL_WHY='npm 설치는 끝났지만 alphaworks --version이 버전을 내지 않아요. 보안 프로그램이 실행을 막았거나 npm 전역 bin이 PATH에 없을 수 있어요'; FAIL_CODE=run_failed
    return 1
  fi
  INSTALLED=$v
}

if [ -z "$CLI" ]; then
  if [ -z "$NPM" ]; then
    # Node가 없음 — 깔지 않음(Node 설치는 사람 승인). 다음 세션에 다시
    log 'install_skipped code=no_node'
    say "알파웍스 CLI가 없고 이 PC에 Node(npm)가 없어 깔지 못했어요. 사람에게 Node 22 이상 설치를 부탁하세요(윈도우 winget install OpenJS.NodeJS.LTS, 맥 · 리눅스는 nodejs.org의 LTS) — 그 뒤 $INSTALL. '시작해줘'(스킬 alphaworks)가 이 순서를 챙겨요.$OLD_NOTE"
    exit 0
  fi
  FAIL_WHY='' FAIL_CODE='' INSTALLED=''
  if install_cli; then
    : >"$STAMP"
    log "installed $INSTALLED"
    say "알파웍스 CLI ${INSTALLED}를 npm으로 설치했어요 (${NEW_CLI}). 이 세션의 셸에서 alphaworks를 못 찾으면 그 전체 경로로 부르세요. 처음이면 '시작해줘'(스킬 alphaworks)로 온보딩을 마치세요.$OLD_NOTE"
  else
    log "install_failed code=$FAIL_CODE $FAIL_WHY"
    # 실패는 다음 세션에 다시 — 시간 표시를 남기지 않음
    say "알파웍스 CLI를 자동으로 설치하지 못했어요. $FAIL_WHY. 다음 세션 시작에 다시 시도해요. 사람에게 이 내용을 전하고, 회사망이 막은 것(network_blocked · tls_intercepted)이면 우회하지 마세요.$OLD_NOTE"
  fi
  exit 0
fi

# 업데이트 — 성공했을 때만 시간 표시(실패 · 망 막힘이면 다음 세션에 다시)
before=$("$CLI" --version 2>/dev/null)
if out=$(CORP_PLATFORM_NO_UPDATE_CHECK=1 "$CLI" self-update --json 2>&1); then
  : >"$STAMP"
  case "$out" in
    *'"changed": true'*)
      after=$("$CLI" --version 2>/dev/null)
      log "updated $before -> $after"
      say "알파웍스 CLI를 ${before}에서 ${after}로 올렸어요.$OLD_NOTE"
      ;;
    *)
      log "same $before"
      [ -n "$OLD_NOTE" ] && say "${OLD_NOTE# }"
      ;;
  esac
else
  log "update_failed $(printf '%s\n' "$out" | tail -n 1)"
fi
exit 0
