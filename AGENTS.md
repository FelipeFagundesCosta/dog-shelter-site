# AGENTS.md — regras para agentes neste repositório

Este repo é operado pelo pipeline WebDev (`~/Documents/WebDev/.orquestracao/pipeline/`): **Analista** (spec + prompts) → **Implementador** (código) → **Tester** (QA), com Spec Kit e portões de qualidade determinísticos.

## Leia antes de agir
1. `.specify/memory/constitution.md` — princípios inegociáveis.
2. A spec da feature em `specs/NNN-nome-curto/` (spec.md, plan.md, tasks.md).
3. Este arquivo.

## Comandos
- Portões de qualidade (harness): `bash scripts/gates.sh . /tmp/gates-out` (cópia do `~/Documents/WebDev/.orquestracao/pipeline/gates.sh`; o orquestrador usa sempre a cópia do pipeline, não a do repo).
- Scripts esperados no `package.json` (quando houver Node): `lint`, `typecheck`, `test` (sem watch), `build`, `test:e2e` (Playwright, quando houver UI).
- Override opcional dos portões: arquivo `.gates` com um comando por linha.

## Git
- Trabalhe só na branch da feature (`NNN-nome-curto`). Nunca commit na `main` (o hook recusa).
- Conventional Commits, commits pequenos (o hook `commit-msg` recusa fora do padrão).
- **Proibido**: push, merge, force-push, PR, `--no-verify`, alterar `core.hooksPath`, git worktree, `cursor-agent --worktree`.
- Nada de segredos; `.env` nunca vai para o git.

## Spec Kit
- Skills em `.cursor/skills/` (speckit-specify, -clarify, -plan, -tasks, -analyze, -implement) e extensões `git` (branch da feature) e `harness` (speckit-harness-init/explore/verify/report: pesquisa com orçamento e verificação de afirmações do plano contra fontes primárias).
- Scripts em `.specify/scripts/bash/`.
