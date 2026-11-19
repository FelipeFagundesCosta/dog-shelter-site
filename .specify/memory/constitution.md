# Constituição — dog-shelter-site

Projeto web criado pelo pipeline WebDev (Analista → Implementador → Tester, Spec Kit + harness). Esta constituição vale para humanos e agentes e prevalece sobre preferências individuais. Mudanças nela exigem commit próprio (`docs(constitution): ...`) e aprovação do Felipe.

## Princípios

### I. Spec-driven (inegociável)
Toda feature nasce de uma spec do Spec Kit em `specs/NNN-nome-curto/` (spec → clarify → plan → tasks) antes de qualquer código de produção. Decisões e premissas ficam registradas na spec/plano. A stack é escolhida por feature/projeto no `plan.md`, com justificativa, e não é superdimensionada.

### II. TypeScript strict e código legível
Código JavaScript/TypeScript usa TypeScript com `"strict": true`. Sem `any` gratuito, sem `@ts-ignore` sem justificativa em comentário. Lint (ESLint ou equivalente) sem avisos. Formatação automática (Prettier ou equivalente). Em Python: type hints, ruff e pyright/mypy.

### III. Testes obrigatórios
Toda mudança de comportamento vem com testes automatizados não interativos: unitários (Vitest/Jest ou pytest) e, quando houver UI, e2e com Playwright cobrindo os fluxos principais. Testes não são apagados nem desativados para "ficar verde". Bug corrigido ganha teste de regressão.

### IV. Portões de qualidade (harness)
O `package.json` expõe scripts padronizados e não interativos: `lint`, `typecheck`, `test`, `build` e `test:e2e` (quando houver e2e). Alternativamente, o arquivo `.gates` lista os comandos. O `gates.sh` do pipeline e o CI (`.github/workflows/ci.yml`) rodam esses portões; qualquer falha reprova a entrega. Lockfile sempre commitado.

### V. Acessibilidade WCAG 2.2 AA
HTML semântico, `lang` definido, um `h1` por página, hierarquia de títulos, contraste AA, foco visível, navegação por teclado, `alt` em imagens, `label` em campos. Verificação automatizada com axe (sem violações `serious`/`critical`).

### VI. Performance e SEO
Sem JavaScript desnecessário; imagens otimizadas e dimensionadas; fontes com `font-display: swap`. Meta: Lighthouse ≥ 90 em Performance, Accessibility, Best Practices e SEO quando aplicável. Cada página tem `<title>`, meta description e Open Graph básico.

### VII. Segurança
Nenhum segredo no repositório (`.env` no `.gitignore`; `.env.example` documenta variáveis). Validação de toda entrada externa. Dependências mínimas e mantidas. Headers de segurança/CSP quando houver servidor. Sem `dangerouslySetInnerHTML`/`innerHTML` com dados não confiáveis.

## Fluxo de trabalho e git
- Branch por feature (`NNN-nome-curto`, convenção do Spec Kit) criada a partir da `main` atualizada. **Nunca** commit direto na `main`.
- Commits pequenos e atômicos em **Conventional Commits** (`feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`).
- Sem push, merge, force-push ou PR por agentes. Push/PR só após aprovação do tester, do orquestrador e do Felipe. Sem git worktree.
- CI obrigatório verde antes de merge.

## Governança
- Versão: 1.0.0 | Ratificada: 2026-11-19 | Última alteração: 2026-11-19
- Emendas: PR próprio com justificativa, incrementando a versão (semver: MAJOR remove/redefine princípio, MINOR adiciona, PATCH esclarece).
