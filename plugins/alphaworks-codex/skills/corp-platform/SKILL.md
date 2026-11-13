---
name: corp-platform
description: 회사 플랫폼(corp-platform)에 앱을 새로 만들거나, 있는 앱을 옮기거나, 배포 · 배포 결과 · 등록 요청을 할 때. "시작해줘", "회사 플랫폼 준비해줘", "앱 만들어줘", "이 앱 회사 플랫폼으로 옮겨줘", "배포해줘", "배포 결과 봐줘"라고 하면 쓴다.
---

# 회사 플랫폼 (corp-platform) — Codex

이 플러그인은 얇은 층이다. 판단과 일은 `corp-platform` CLI와 회사 플랫폼 MCP가 한다. 너는 CLI · MCP가 준 `say`를 사람에게 그대로 전하고, `ask`를 묻고, `next`를 순서대로 한다.

## 시작해줘 (처음 한 번 — 온보딩)

순서대로 하고, 끝난 단계는 건너뛴다.

1. **CLI** — `corp-platform --version`. 안 되면 `~/.corp-platform/bin/corp-platform --version`. 둘 다 안 되면 직접 설치한다(사람에게 부탁하지 않음 — 로그인 · Node · 토큰 없음):
   - 맥 · 리눅스 · Git Bash: `curl -fsSL https://storage.googleapis.com/alphabrothers-corp-platform-cli/install.sh | bash`
   - 윈도우 PowerShell: `irm https://storage.googleapis.com/alphabrothers-corp-platform-cli/install.ps1 | iex`
   설치가 `CORP_PLATFORM_INSTALL_ERROR code=…`로 끝나면 그 줄을 사람에게 전한다. `network_blocked` · `tls_intercepted`는 회사망 · 보안 프로그램이 막은 것이라 우회하지 않고 멈춘다. 설치 뒤 이 세션에서 `corp-platform`을 못 찾으면 전체 경로로 부른다.
2. **PC 점검** — `corp-platform setup --json`. `say`를 전하고, "사람이 할 것"(GitHub 로그인 — 브라우저 승인)은 그 명령(`gh auth login -h github.com`)을 사람에게 알려 직접 하게 한다.
3. **MCP 로그인** — 이 플러그인이 회사 플랫폼 MCP(`https://mcp.corp.ai-team.kr/mcp`, 이름 `corp-platform`)를 붙인다. 사람에게 터미널에서 `codex mcp login corp-platform`을 치고 브라우저에서 회사 계정으로 로그인(허용 화면의 도구 이름이 "Codex"인지)하게 한다. Codex는 만료된 연결을 저절로 잇지 않아 "다시 로그인"이 나오면 같은 명령을 다시 친다. 비밀번호 · 인증 코드는 묻지 않는다. 예전에 `codex mcp add`로 손으로 붙인 `corp-platform`이 있으면 둘 중 하나만 쓰면 된다고 알린다.
4. **허용 목록** — 매번 승인을 묻지 않게 하려면 사람의 동의를 받고 `~/.codex/rules/default.rules`에 아래 한 줄을 더한다(파일이 없으면 만들고, 다른 줄은 건드리지 않음):
   `prefix_rule(pattern=["corp-platform"], decision="allow")`
   MCP의 `diagnose` · `read_logs` · `redeploy`는 플랫폼이 매번 묻게 해 둠.
5. **끝** — 사람에게 준비됐다고 말하고, 무엇을 할지(새 앱 · 있는 앱 옮기기 · 배포 결과 보기) 묻는다.

## 일할 때

- 지침을 먼저 읽는다 — 이 저장소가 등록된 앱이면 MCP `app_guide`, 아니면 `corp-platform agents-md`. 그 지침의 "배포 흐름"을 따른다. 이 스킬과 다르면 지침이 우선한다.
- CLI 명령은 늘 `--json`으로 부른다(응답 계약 — `say` · `ask` · `next`).
- `corp-platform setup` · `diagnose`가 새 CLI를 알리면(`next`의 `update_cli`) 그 `command`(보통 `corp-platform self-update --json`)를 먼저 실행하고 같은 명령을 다시 한다. 이 플러그인도 하루 한 번 세션을 열 때 뒤에서 올린다(맥 · 리눅스 — 윈도우는 그때그때 `self-update`).
- 사람만 할 수 있는 것(브라우저 승인 · 비밀값 넣기 · 등록 승인)은 대신하지 않는다.
