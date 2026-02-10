# Инструкции для extractor-agent

> **Тип:** downstream-instrument
> **Source-of-truth:** `DP.AISYS.013` (spf-digital-platform-pack)
> **Upstream:** spf-digital-platform-pack → SPF → FPF

## Назначение

Knowledge Extractor — ИИ-система, которая трансформирует информацию в формализованные Pack-совместимые сущности.

## Процессы

Все процессы описаны в `PROCESSES.md` этого репо.

| Процесс | Статус |
|---------|--------|
| Session-Close Extraction | Готов к тесту | `prompts/session-close.md` |
| On-Demand Extraction | Готов к тесту | `prompts/on-demand.md` |
| Bulk Extraction | Готов к тесту | `prompts/bulk-extraction.md` |
| Cross-Repo Sync | Готов к тесту | `prompts/cross-repo-sync.md` |
| Knowledge Audit | Готов к тесту | `prompts/knowledge-audit.md` |

## Правила

1. **Human-in-the-loop:** KE всегда предлагает, никогда не пишет без одобрения
2. **Формализация обязательна:** информация → экстракция → знание (нарушение = FM.001)
3. **Именование файлов:** `{PREFIX}.{TYPE}.{NNN}-{slug}.md` (детали в PROCESSES.md)
4. **Один пайплайн:** все процессы используют classify → route → formalize → validate

## Связанные документы (Pack)

- `DP.AISYS.013` — паспорт ИИ-системы
- `DP.METHOD.001` — метод экстракции знаний
- `DP.WP.001` — отчёт экстракции
- `DP.FM.001` — failure mode: информация как знание

## Конвенция именования агентов

Репозитории ИИ-систем: `{slug}-agent` (пример: `strategist-agent`, `extractor-agent`).
Привязка к Pack через `source-of-truth` в CLAUDE.md, не через имя репо.

---

*Последнее обновление: 2026-02-10*
