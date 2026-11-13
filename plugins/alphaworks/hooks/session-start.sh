#!/usr/bin/env bash
# 세션 시작 훅 — corp-platform CLI가 없으면 깔고, 하루 한 번 새 판으로 올림 (planning/55-CLI-단일바이너리 "업데이트" · 52-사용성개선 "2. CLI는 공개 CDN, 플러그인은 CLI 래퍼")
# hooks.json이 async로 등록 — 세션을 막지 않고 뒤에서 돎. 바뀐 것이 있을 때만 마지막 줄 JSON(additionalContext)으로 에이전트에게 한 줄 알림
# CLI가 혼자 바꾸지 않음 — 이 훅이 `corp-platform self-update`를 부르는 것뿐. 끄기: CORP_PLATFORM_NO_AUTO_UPDATE=1 또는 ~/.corp-platform/no-auto-update 파일
# 사본: Claude Code용(plugins/alphaworks)과 Codex용(plugins/alphaworks-codex)이 글자 그대로 같음 — scripts/test/plugins.test.ts가 견줌
# NOTE: 비밀값 · 토큰 없음. 받는 곳은 공개 설치 자리 하나(설치 스크립트 · self-update가 sha256 · 서명 확인). 윈도우 Codex는 hooks.json이 건너뜀(PowerShell 설치는 스킬이 안내)
host=${1:-claude}
[ -n "${CORP_PLATFORM_NO_AUTO_UPDATE:-}" ] && exit 0
[ -f "$HOME/.corp-platform/no-auto-update" ] && exit 0

INSTALL_URL='https://storage.googleapis.com/alphabrothers-corp-platform-cli/install.sh'
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

# 단일 실행 파일 자리 — npm으로 깐 예전 판은 self-update를 못 하므로 이 자리를 봄
BIN=''
for candidate in "$DIR/bin/corp-platform" "$DIR/bin/corp-platform.exe"; do
  [ -x "$candidate" ] && { BIN=$candidate; break; }
done

if [ -z "$BIN" ]; then
  # 없으면 설치 (공개 자리 — 인증 없음). 셸 시작 파일에 PATH 한 줄(백업 뒤) — 새 창부터
  if out=$(curl -fsSL "$INSTALL_URL" 2>/dev/null | bash 2>&1); then
    : >"$STAMP"
    v=$("$DIR/bin/corp-platform" --version 2>/dev/null || "$DIR/bin/corp-platform.exe" --version 2>/dev/null)
    log "installed $v"
    say "corp-platform CLI ${v}를 설치했어요 ($DIR/bin). 이 세션의 셸에서 corp-platform을 못 찾으면 $DIR/bin/corp-platform 전체 경로로 부르세요. 처음이면 '시작해줘'(스킬 corp-platform)로 온보딩을 마치세요."
  else
    last=$(printf '%s\n' "$out" | tail -n 1)
    log "install_failed $last"
    # 실패는 다음 세션에 다시 — 시간 표시를 남기지 않음
    say "corp-platform CLI를 자동으로 설치하지 못했어요 ($last). 사람에게 이 줄을 전하고, 회사망이 막은 것(network_blocked · tls_intercepted)이면 우회하지 마세요."
  fi
  exit 0
fi

: >"$STAMP"
before=$("$BIN" --version 2>/dev/null)
if out=$(CORP_PLATFORM_NO_UPDATE_CHECK=1 "$BIN" self-update --json 2>&1); then
  case "$out" in
    *'"changed": true'*)
      after=$("$BIN" --version 2>/dev/null)
      log "updated $before -> $after"
      say "corp-platform CLI를 $before에서 $after로 올렸어요."
      ;;
    *) log "same $before" ;;
  esac
else
  log "update_failed $(printf '%s\n' "$out" | tail -n 1)"
fi
exit 0
