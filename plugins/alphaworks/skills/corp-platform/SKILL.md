---
name: corp-platform
description: 회사 플랫폼(corp-platform)에 앱을 새로 만들거나, 있는 앱을 옮기거나, 배포 · 배포 결과 · 등록 요청을 할 때. "시작해줘", "회사 플랫폼 준비해줘", "앱 만들어줘", "이 앱 회사 플랫폼으로 옮겨줘", "배포해줘", "배포 결과 봐줘"라고 하면 쓴다.
---

# 회사 플랫폼 (corp-platform) — Claude Code

이 플러그인은 얇은 층이다. 판단과 일은 `corp-platform` CLI와 회사 플랫폼 MCP가 한다. 너는 CLI · MCP가 준 `say`를 사람에게 그대로 전하고, `ask`를 묻고, `next`를 순서대로 한다.

## 시작해줘 (처음 한 번 — 온보딩)

순서대로 하고, 끝난 단계는 건너뛴다.

1. **CLI** — `corp-platform --version`. 안 되면 `~/.corp-platform/bin/corp-platform --version`. 둘 다 안 되면 직접 설치한다(사람에게 부탁하지 않음 — 로그인 · Node · 토큰 없음):
   `curl -fsSL https://storage.googleapis.com/alphabrothers-corp-platform-cli/install.sh | bash`
   설치가 `CORP_PLATFORM_INSTALL_ERROR code=…`로 끝나면 그 줄을 사람에게 전한다. `network_blocked` · `tls_intercepted`는 회사망 · 보안 프로그램이 막은 것이라 우회하지 않고 멈춘다. 설치 뒤 이 세션에서 `corp-platform`을 못 찾으면 전체 경로(`~/.corp-platform/bin/corp-platform`)로 부른다.
2. **PC 점검** — `corp-platform setup --json`. `say`를 전하고, "사람이 할 것"(GitHub 로그인 — 브라우저 승인)은 그 명령을 사람에게 알려 직접 하게 한다(입력창에 `! gh auth login -h github.com`).
3. **MCP 로그인** — 이 플러그인이 회사 플랫폼 MCP(`https://mcp.corp.ai-team.kr/mcp`)를 붙인다. 사람에게 입력창에 `/mcp`를 치고 플러그인 `alphaworks`의 `corp-platform`을 골라 로그인(브라우저 — 회사 계정, 허용 화면의 도구 이름이 "Claude Code"인지)하게 한다. 비밀번호 · 인증 코드는 묻지 않는다. 예전에 손으로 붙인 `corp-platform`(사용자 설정)이 따로 보이면 둘 중 하나만 쓰면 된다고 알린다 — 지우는 것은 사람이 정한다(`claude mcp remove corp-platform -s user`).
4. **허용 목록** — 매번 "허용할까요?"가 뜨지 않게 하려면 사람의 동의를 받고 사용자 설정 `~/.claude/settings.json`의 `permissions.allow`에 아래만 더한다(다른 줄은 건드리지 않음, 회사 관리형 설정으로 이미 들어 있으면 건너뜀). 읽기만 하는 MCP 도구와 CLI 하나다:
   - `Bash(corp-platform:*)` · `Bash(~/.corp-platform/bin/corp-platform:*)`
   - 이 플러그인 MCP의 읽기 도구 넷 `list_my_apps` · `app_guide` · `app_status` · `deploy_result` (`/mcp`에 보이는 이 서버의 도구 이름 그대로 — 보통 `mcp__plugin_alphaworks_corp-platform__<도구>`)
   `diagnose` · `read_logs` · `redeploy`는 넣지 않는다(플랫폼이 매번 묻게 해 둠).
5. **끝** — 사람에게 준비됐다고 말하고, 무엇을 할지(새 앱 · 있는 앱 옮기기 · 배포 결과 보기) 묻는다.

## 일할 때

- 지침을 먼저 읽는다 — 이 저장소가 등록된 앱이면 MCP `app_guide`, 아니면 `corp-platform agents-md`. 그 지침의 "배포 흐름"을 따른다. 이 스킬과 다르면 지침이 우선한다.
- CLI 명령은 늘 `--json`으로 부른다(응답 계약 — `say` · `ask` · `next`).
- `corp-platform setup` · `diagnose`가 새 CLI를 알리면(`next`의 `update_cli`) 그 `command`(보통 `corp-platform self-update --json`)를 먼저 실행하고 같은 명령을 다시 한다. 이 플러그인도 하루 한 번 세션을 열 때 뒤에서 올린다.
- 사람만 할 수 있는 것(브라우저 승인 · 비밀값 넣기 · 등록 승인)은 대신하지 않는다.
