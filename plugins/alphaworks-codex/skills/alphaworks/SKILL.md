---
name: alphaworks
description: 알파웍스(AlphaWorks)에 앱을 새로 만들거나, 있는 앱을 옮기거나, 배포 · 배포 결과 · 등록 요청을 할 때. "시작해줘", "알파웍스 준비해줘", "앱 만들어줘", "이 앱 알파웍스로 옮겨줘", "배포해줘", "배포 결과 봐줘"라고 하면 쓴다. 예전 이름 "회사 플랫폼"으로 말해도 이것이다.
---

# 알파웍스 (AlphaWorks) — Codex

이 플러그인은 얇은 층이다. 판단과 일은 `alphaworks` CLI와 알파웍스 MCP가 한다. 너는 CLI · MCP가 준 `say`를 사람에게 그대로 전하고, `ask`를 묻고, `next`를 순서대로 한다.

## 시작해줘 (처음 한 번 — 온보딩)

순서대로 하고, 끝난 단계는 건너뛴다. 단계마다 무엇을 하는지 한 줄로 먼저 말한다. 사람 손이 필요한 곳(브라우저 승인 · 비밀번호 창 · 동의)에서는 멈추고 기다린다.

1. **GitHub 도구** — `gh --version`. 없으면 설치해도 되는지 묻고, 동의하면 설치한다:
   - 맥: `brew`가 있으면 `brew install gh`. 없으면 사람에게 https://cli.github.com 에서 macOS 설치 파일을 받아 열게 한다
   - 윈도우: `winget install --id GitHub.cli -e` (관리자 확인 창은 사람이 누름)
   - 리눅스: 배포판 패키지 관리자(`sudo`는 사람에게 묻고)
   그다음 `gh auth status -h github.com`. 로그인이 안 돼 있으면 사람에게 터미널에서 `gh auth login -h github.com`을 치게 하고, 브라우저에 코드를 넣고 **승인**하게 한다(회사 조직 AlphaBrothers-Corp 멤버 계정 — 초대를 아직 수락하지 않았으면 메일의 초대부터 수락). 승인은 대신 못 한다.
2. **CLI** — `alphaworks --version`. 안 되면 `~/.corp-platform/bin/alphaworks --version`(설치 폴더 이름은 예전 그대로). 예전에 깐 CLI라 `corp-platform`만 되면 `corp-platform self-update --json`으로 올린다 — 올리면 `alphaworks`도 생긴다. 둘 다 안 되면 직접 설치한다(사람에게 부탁하지 않음 — 로그인 · Node · 토큰 없음):
   - 맥 · 리눅스 · Git Bash: `curl -fsSL https://github.com/AlphaBrothers-Corp/alphaworks-cli/releases/latest/download/install.sh | bash`
   - 윈도우 PowerShell: `irm https://github.com/AlphaBrothers-Corp/alphaworks-cli/releases/latest/download/install.ps1 | iex`
   설치가 `CORP_PLATFORM_INSTALL_ERROR code=…`로 끝나면 그 줄을 사람에게 전한다. `network_blocked` · `tls_intercepted`는 회사망 · 보안 프로그램이 막은 것이라 우회하지 않고 멈춘다. 보안 프로그램이 실행을 막으면(서명 없는 파일 차단 등) 우회하지 않고 IT에 허용을 요청하라고 전한다. 설치 뒤 이 세션에서 `alphaworks`를 못 찾으면 전체 경로로 부른다.
   그다음 `alphaworks setup --json`으로 PC를 점검하고 `say`를 전한다. 내 PC에서 앱을 띄워 볼 때만 Node 22 · Docker가 필요하다 — 없으면 알리기만 한다.
3. **알파웍스 연결(MCP)** — 이 플러그인이 알파웍스 MCP(`https://mcp.corp.ai-team.kr/mcp`, 서버 이름은 예전 그대로 `corp-platform`)를 붙인다. 사람에게 터미널에서 `codex mcp login corp-platform`을 치고 브라우저에서 회사 로그인 · 2단계 인증 → 허용 화면의 도구 이름이 "Codex"인지 보고 **허용**하게 한다. 플러그인을 쓸 수 없는 환경이면 동의를 받고 `codex mcp add corp-platform --url https://mcp.corp.ai-team.kr/mcp`로 붙인다(`--oauth-resource`는 붙이지 않음). Codex는 만료된 연결을 저절로 잇지 않아 "다시 로그인"이 나오면 같은 login 명령을 다시 친다. 예전에 `codex mcp add`로 손으로 붙인 `corp-platform`이 있으면 둘 중 하나만 쓰면 된다고 알린다. 비밀번호 · 인증 코드는 묻지 않는다.
   연결 확인: MCP 도구 `list_my_apps`를 부른다. 답이 오면(빈 목록이어도) 연결된 것이다. 도구가 없거나 인증 오류면 로그인이 아직이다 — 이 단계를 건너뛰지 않는다(이게 없으면 배포 결과 · 로그를 못 읽는다).
4. **허용 목록** — 매번 승인을 묻지 않게, 사람에게 무엇을 넣는지 보여 주고 동의를 받은 뒤 `~/.codex/rules/default.rules`에 아래 두 줄을 더한다(파일이 없으면 만들고, 다른 줄은 건드리지 않음):
   `prefix_rule(pattern=["alphaworks"], decision="allow")`
   `prefix_rule(pattern=["corp-platform"], decision="allow")` (옛 이름 — 옛 이름으로 부르는 지침 · 앱 저장소가 아직 있어서 같이 둔다)
   MCP의 `diagnose` · `read_logs` · `redeploy`는 플랫폼이 매번 묻게 해 둠.
5. **끝** — 준비됐다고 말하고, 사용법 문서는 알파웍스의 `https://portal.corp.ai-team.kr/docs`(알파웍스 로그인 뒤)라고 알린다. 처음이면 「말로 첫 앱 만들기」(`https://portal.corp.ai-team.kr/docs/start/first-app/`)를 권한다. MCP가 붙었으면 `docs_search` · `read_doc`으로 그 문서를 직접 읽을 수 있다. 그리고 무엇을 할지(새 앱 · 있는 앱 옮기기 · 배포 결과 보기) 묻는다.

## 일할 때

- 지침을 먼저 읽는다 — 이 저장소가 등록된 앱이면 MCP `app_guide`, 아니면 `alphaworks agents-md`. 그 지침의 "배포 흐름"을 따른다. 이 스킬과 다르면 지침이 우선한다.
- CLI 명령은 늘 `--json`으로 부른다(응답 계약 — `say` · `ask` · `next`).
- `alphaworks setup` · `diagnose`가 새 CLI를 알리면(`next`의 `update_cli`) 그 `command`(보통 `alphaworks self-update --json`)를 먼저 실행하고 같은 명령을 다시 한다. 이 플러그인도 하루 한 번 세션을 열 때 뒤에서 올린다(맥 · 리눅스 — 윈도우는 그때그때 `self-update`).
- 앱 등록은 사람이 한다 — `alphaworks request --json`이 준 `registerUrl`(알파웍스 "앱 등록" 화면)을 전하고, 사람이 열어 **등록 요청**을 누르게 한다. 서버가 진단해 문제가 없으면 바로 등록하고 첫 배포까지 한다. 그다음 MCP `deploy_result`로 결과를 본다.
- 사람만 할 수 있는 것(브라우저 승인 · 비밀값 넣기 · 알파웍스 등록 요청)은 대신하지 않는다. 비밀값 값은 받지 않는다 — 알파웍스 앱 관리 > 설정 > 비밀값에 사람이 넣는다.
