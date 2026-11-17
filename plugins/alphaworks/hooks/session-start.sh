#!/usr/bin/env bash
# 세션 시작 훅 — 알파웍스 CLI(alphaworks)가 없으면 깔고, 하루 한 번 새 판으로 올림 (planning/55-CLI-단일바이너리 "업데이트" · 52-사용성개선 "2. CLI는 공개 CDN, 플러그인은 CLI 래퍼")
# hooks.json이 async로 등록 — 세션을 막지 않고 뒤에서 돎. 바뀐 것이 있을 때만 마지막 줄 JSON(additionalContext)으로 에이전트에게 한 줄 알림
# CLI가 혼자 바꾸지 않음 — 이 훅이 `alphaworks self-update`를 부르는 것뿐. 끄기: CORP_PLATFORM_NO_AUTO_UPDATE=1 또는 ~/.corp-platform/no-auto-update 파일
# 사본: Claude Code용(plugins/alphaworks)과 Codex용(plugins/alphaworks-codex)이 글자 그대로 같음 — scripts/test/plugins.test.ts가 견줌
# NOTE: 비밀값 · 토큰 없음. 받는 곳은 공개 저장소의 GitHub Releases 하나(설치 스크립트 · self-update가 sha256 · 서명 확인). 윈도우 Codex는 hooks.json이 건너뜀(PowerShell 설치는 스킬이 안내)
host=${1:-claude}
[ -n "${CORP_PLATFORM_NO_AUTO_UPDATE:-}" ] && exit 0
[ -f "$HOME/.corp-platform/no-auto-update" ] && exit 0

INSTALL_URL='https://github.com/AlphaBrothers-Corp/alphaworks-cli/releases/latest/download/install.sh'
# 주소를 바꿔 볼 때(시험) — 설치 스크립트 · self-update와 같은 변수(`…/releases` 모양)
[ -n "${CORP_PLATFORM_CLI_BASE_URL:-}" ] && INSTALL_URL="${CORP_PLATFORM_CLI_BASE_URL%/}/latest/download/install.sh"
DIR="$HOME/.corp-platform"
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

# 단일 실행 파일 자리 — npm으로 깐 예전 판은 self-update를 못 하므로 이 자리를 봄. 새 이름 alphaworks, 없으면 옛 이름(옛 판 — self-update 한 번이면 새 이름도 생김, #609)
BIN=''
for candidate in "$DIR/bin/alphaworks" "$DIR/bin/alphaworks.exe" "$DIR/bin/corp-platform" "$DIR/bin/corp-platform.exe"; do
  [ -x "$candidate" ] && { BIN=$candidate; break; }
done

# 설치 — 받기와 실행을 나눔(#566). `curl … | bash`는 받기가 403 · 망 막힘이어도 빈 입력의 bash가 0을 돌려줘 성공처럼 보임
# 성공은 설치 뒤 alphaworks --version이 버전을 낼 때만. 실패면 시간 표시를 남기지 않아 다음 세션 시작에 다시 시도
install_cli() {
  local script="$CACHE/install.sh.$$" http code=0 out v
  http=$(curl -sSL --connect-timeout 15 --max-time 120 -o "$script" -w '%{http_code}' "$INSTALL_URL" 2>/dev/null) || code=$?
  if [ "$code" != 0 ] || [ "$http" != 200 ]; then
    rm -f "$script"
    case "$code" in
      6 | 7 | 28 | 52 | 56) FAIL_WHY="설치 주소에 닿지 못했어요. 회사망 · VPN · 프록시가 github.com을 막았거나 GitHub가 잠시 안 될 수 있어요 (curl $code)"; FAIL_CODE=network_blocked ;;
      35 | 51 | 58 | 60 | 77) FAIL_WHY="보안 연결(TLS)을 확인하지 못했어요. 회사 보안 프로그램이 연결을 가로챘을 수 있어요 (curl $code)"; FAIL_CODE=tls_intercepted ;;
      0) FAIL_WHY="설치 스크립트를 받지 못했어요 (HTTP $http). GitHub 장애이거나 회사망이 막았을 수 있어요"; FAIL_CODE=network_blocked ;;
      *) FAIL_WHY="설치 스크립트를 받지 못했어요 (curl $code)"; FAIL_CODE=network_blocked ;;
    esac
    return 1
  fi
  # 비었거나 셸 스크립트가 아니면(회사 프록시의 로그인 · 차단 화면 등) 실행하지 않음
  if [ ! -s "$script" ] || [ "$(head -c 2 "$script")" != '#!' ]; then
    rm -f "$script"
    FAIL_WHY='받은 설치 스크립트가 비었거나 스크립트가 아니에요. 회사 프록시가 응답을 바꿨을 수 있어요'; FAIL_CODE=network_blocked
    return 1
  fi
  out=$(bash "$script" 2>&1) || code=$?
  rm -f "$script"
  if [ "$code" != 0 ]; then
    FAIL_CODE=$(printf '%s\n' "$out" | sed -n 's/^CORP_PLATFORM_INSTALL_ERROR code=\([a-z_]*\).*/\1/p' | tail -n 1)
    FAIL_WHY="설치 스크립트가 실패했어요 ($(printf '%s\n' "$out" | tail -n 1))"; FAIL_CODE=${FAIL_CODE:-unknown}
    return 1
  fi
  v=$("$DIR/bin/alphaworks" --version 2>/dev/null || "$DIR/bin/alphaworks.exe" --version 2>/dev/null || "$DIR/bin/corp-platform" --version 2>/dev/null || "$DIR/bin/corp-platform.exe" --version 2>/dev/null || true)
  if ! printf '%s' "$v" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+'; then
    FAIL_WHY='설치는 끝났다고 했지만 alphaworks --version이 버전을 내지 않아요. 보안 프로그램이 실행을 막았을 수 있어요'; FAIL_CODE=run_failed
    return 1
  fi
  INSTALLED=$v
}

if [ -z "$BIN" ]; then
  # 없으면 설치 (공개 릴리스 — 인증 없음). 셸 시작 파일에 PATH 한 줄(백업 뒤) — 새 창부터
  FAIL_WHY='' FAIL_CODE='' INSTALLED=''
  if install_cli; then
    : >"$STAMP"
    log "installed $INSTALLED"
    say "알파웍스 CLI ${INSTALLED}를 설치했어요 ($DIR/bin). 이 세션의 셸에서 alphaworks를 못 찾으면 $DIR/bin/alphaworks 전체 경로로 부르세요. 처음이면 '시작해줘'(스킬 alphaworks)로 온보딩을 마치세요."
  else
    log "install_failed code=$FAIL_CODE $FAIL_WHY"
    # 실패는 다음 세션에 다시 — 시간 표시를 남기지 않음
    say "알파웍스 CLI를 자동으로 설치하지 못했어요. $FAIL_WHY. 다음 세션 시작에 다시 시도해요. 사람에게 이 내용을 전하고, 회사망이 막은 것(network_blocked · tls_intercepted)이면 우회하지 마세요."
  fi
  exit 0
fi

# 업데이트 — 성공했을 때만 시간 표시(실패 · 망 막힘이면 다음 세션에 다시)
before=$("$BIN" --version 2>/dev/null)
if out=$(CORP_PLATFORM_NO_UPDATE_CHECK=1 "$BIN" self-update --json 2>&1); then
  : >"$STAMP"
  case "$out" in
    *'"changed": true'*)
      after=$("$BIN" --version 2>/dev/null)
      log "updated $before -> $after"
      say "알파웍스 CLI를 ${before}에서 ${after}로 올렸어요."
      ;;
    *) log "same $before" ;;
  esac
else
  log "update_failed $(printf '%s\n' "$out" | tail -n 1)"
fi
exit 0
