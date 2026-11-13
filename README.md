# 알파웍스 플러그인 (Claude Code · Codex)

알파웍스(회사 플랫폼 — 이름은 가제)에 앱을 만들고 옮기고 배포할 때 쓰는 플러그인이에요. 플러그인은 얇은 층이고, 일은 `corp-platform` CLI와 회사 플랫폼 MCP가 해요.

| 플러그인 | 도구 | 하는 일 |
| --- | --- | --- |
| `alphaworks` | Claude Code (터미널 · Desktop Code 탭) | CLI가 없으면 설치, 하루 한 번 `corp-platform self-update`, 회사 플랫폼 MCP(`corp-platform`) 연결, "시작해줘" 온보딩 · 지침 스킬 |
| `alphaworks-codex` | Codex CLI · ChatGPT Desktop Codex 모드 | 같은 일 (윈도우는 세션 시작 훅을 건너뛰고 스킬이 PowerShell 설치를 안내) |

비밀값은 없어요. CLI는 공개 자리에서 받고(sha256 · 서명 확인), MCP 로그인은 각 사람이 브라우저에서 회사 계정으로 해요.

## 설치

Claude Code — 입력창에 두 줄:

```
/plugin marketplace add AlphaBrothers-Corp/alphaworks-plugins
/plugin install alphaworks@alphaworks
```

Codex — 터미널에 두 줄:

```
codex plugin marketplace add https://github.com/AlphaBrothers-Corp/alphaworks-plugins
codex plugin add alphaworks-codex@alphaworks
```

설치한 뒤 새 세션에서 **"시작해줘"** 라고 하면 CLI 설치 · PC 점검 · MCP 로그인 · 허용 목록까지 차례로 해요.

- 공개 마켓플레이스라 Claude Code의 자동 업데이트는 기본 꺼짐이에요 — `/plugin`에서 이 마켓플레이스의 자동 업데이트를 켜 주세요. 플러그인은 버전을 고정하지 않아서 저장소가 바뀌면 새 판이 가요
- Codex는 처음 세션에서 플러그인 훅을 믿을지 물어요. 믿지 않으면 하루 한 번 업데이트만 꺼지고, 스킬은 그대로 돼요. 플러그인 업데이트는 Codex를 다시 열어야 반영돼요
- 회사 관리형 설정(Claude Team Owner)이 있는 조직은 `extraKnownMarketplaces`(`AlphaBrothers-Corp/alphaworks-plugins`) · `enabledPlugins`(`alphaworks@alphaworks`) · `permissions.allow`로 한 번에 넣을 수 있어요
- 예전에 `claude mcp add` · `codex mcp add`로 손으로 붙인 `corp-platform`이 있으면 둘 중 하나만 쓰면 돼요
- 하루 한 번 업데이트를 끄려면 `CORP_PLATFORM_NO_AUTO_UPDATE=1` 또는 `~/.corp-platform/no-auto-update` 파일. 기록은 `~/.corp-platform/cache/plugin-update.log`

## 원본 · 동기화 (운영자)

원본은 비공개 플랫폼 저장소 `AlphaBrothers-Corp/corp-platform`의 `plugins/marketplace/`이고, 이 공개 저장소 `AlphaBrothers-Corp/alphaworks-plugins`는 그 사본이에요. **이 저장소에서 직접 고치지 않아요** — 원본을 고친 PR이 main에 병합된 뒤 운영자가 맞춰요.

1. 플랫폼 저장소의 main 머리를 받은 깨끗한 worktree에서
2. `gh repo clone AlphaBrothers-Corp/alphaworks-plugins <클론 폴더>`(처음 한 번, 이미 있으면 `git -C <클론 폴더> pull`)
3. `bash scripts/plugins-sync-local.sh <클론 폴더>` — 원본 시험을 돌린 뒤 `.git`만 남기고 원본으로 맞춤(지운 파일도 지움), 바뀐 파일을 보여 줌. 커밋 · push는 하지 않음
4. 클론 폴더에서 `git diff`를 보고 `git add -A && git commit -m "corp-platform@<짧은 해시>에서 맞춤" && git push`

| 자리 | 무엇 |
| --- | --- |
| `.claude-plugin/marketplace.json` | Claude Code 마켓플레이스 `alphaworks` — 플러그인 `alphaworks` |
| `.agents/plugins/marketplace.json` | Codex 마켓플레이스 `alphaworks` — 플러그인 `alphaworks-codex` |
| `plugins/alphaworks/` | Claude Code용 — `.claude-plugin/plugin.json` · `.mcp.json` · `hooks/` · `skills/corp-platform/SKILL.md` |
| `plugins/alphaworks-codex/` | Codex용 — `.codex-plugin/plugin.json`(스킬 · MCP · 훅 자리를 적음) · 같은 모양 |

같이 고칠 것 — 플랫폼 저장소의 시험 `scripts/test/plugins.test.ts`가 봄:

- 설치 한 줄 · MCP 주소는 `packages/agent-kit/src/install.ts` `INSTALL_COMMAND` · `INSTALL_COMMAND_POWERSHELL`, 회사 도메인(`mcp.{도메인}/mcp`)과 같은 글자
- 세션 시작 훅 `hooks/session-start.sh`는 두 벌이 글자 그대로 같음
- `plugin.json`에 `version`을 적지 않음(적으면 그 글자를 바꾸기 전까지 업데이트가 안 감)
- 비밀값 · 토큰 · 내부 주소를 넣지 않음 — 공개 저장소
- CLI 명령 · 패키지 범위 · 환경변수 · MCP 서버 이름은 `corp-platform` 그대로(알파웍스는 가제 — 플러그인 · 마켓플레이스 이름만)
