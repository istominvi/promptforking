# CLAUDE.md

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:

- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:

- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:

- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:

- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:

```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.

# Promptforking — инструкции для Claude

Общие инструкции для всех AI-агентов проекта — в [AGENTS.md](AGENTS.md). Архитектура, домен, схема БД и навигация — в [`docs/`](docs/) (`ARCHITECTURE.md`, `TECHNICAL_SPEC.md`, `DATABASE.md`, `NAVIGATION.md`). Этот файл содержит только Claude-специфические инструкции.

## Доступ к базе данных через MCP

В этом проекте настроен прямой доступ к живой PostgreSQL базе через Supabase MCP. **Не читай миграции, чтобы понять текущее состояние схемы — иди сразу в БД через MCP.**

### Доступные инструменты

Read-only:

- `execute_sql` — произвольный SQL (SELECT/DML)
- `list_tables`, `list_extensions`, `list_migrations`
- `get_logs` (за последние 24 часа), `get_advisors` (security/performance)
- `get_project_url`, `get_publishable_keys`
- `generate_typescript_types`, `search_docs`

DDL:

- `apply_migration` — применить миграцию (для `ALTER` / `CREATE` / `DROP`)

### Как вызывать

**Способ 1 — деферные tools `mcp__supabase__*`.** Если в текущей сессии они есть в списке deferred tools, подгружай через ToolSearch и вызывай напрямую — это самый удобный путь.

**Способ 2 (fallback) — прокси-скрипт через stdin.** Если деферные `mcp__supabase__*` в сессии не появились (бывает при перезапуске MCP-сервера или смене окружения), используй Bash + прокси. Скрипт сам подкладывает токен и URL — никаких секретов в аргументах:

```bash
# Произвольный SQL
echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"execute_sql","arguments":{"query":"SELECT count(*) FROM public.work_segments;"}}}' \
  | ~/.claude/bin/supabase-mcp-proxy.sh

# DDL-миграция (формируем payload через python3, чтобы не воевать с экранированием SQL)
PAYLOAD=$(python3 -c '
import json
print(json.dumps({
  "jsonrpc":"2.0","id":1,"method":"tools/call",
  "params":{
    "name":"apply_migration",
    "arguments":{"name":"my_migration","query":"ALTER TABLE ..."}
  }
}))')
echo "$PAYLOAD" | ~/.claude/bin/supabase-mcp-proxy.sh
```

Удобно прогонять ответ через `| python3 -c "import json,sys; r=json.load(sys.stdin); print(r['result']['content'][0]['text'])"` — это вытащит чистый текст результата без MCP-обёртки.

Список доступных tools у живого сервера всегда можно перезапросить:

```bash
echo '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' \
  | ~/.claude/bin/supabase-mcp-proxy.sh
```

### Где лежат секреты

MCP-сервер `supabase` зарегистрирован в `~/.claude/settings.json`. Токен и URL подставляет сам прокси-скрипт `~/.claude/bin/supabase-mcp-proxy.sh`. Проектные permissions для вызовов через Bash — в `.claude/settings.local.json`. **Никогда не клади токены в код, в CLAUDE.md, в коммиты, в PR-описания или в ответы пользователю — они существуют только в этих локальных файлах.**

### Типичные запросы

- Структура таблицы → `SELECT * FROM information_schema.columns WHERE table_name = '...'`
- Constraints / индексы → `pg_constraint`, `pg_indexes`
- Функции / триггеры → `pg_proc`, `pg_trigger`, `pg_get_functiondef`
- Политики RLS → `pg_policies`
- Данные / проверка логики → `execute_sql`

## Язык общения

- Со мной разговаривай на русском.
- Описания PR (title и body) пиши на русском.
