#!/bin/bash
# Knowledge Extractor Agent Runner
# Запускает Claude Code с заданным процессом KE
#
# Использование:
#   extractor.sh inbox-check     # headless: обработка inbox (launchd)
#   extractor.sh audit           # headless: аудит Pack'ов
#   extractor.sh session-close   # convenience wrapper
#   extractor.sh on-demand       # convenience wrapper
#   extractor.sh bulk <file>     # обработка документа
#   extractor.sh cross-sync      # синхронизация Pack → downstream
#   extractor.sh ontology-sync   # синхронизация онтологий

set -e

# Конфигурация
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
WORKSPACE="$HOME/Github"
PROMPTS_DIR="$REPO_DIR/prompts"
LOG_DIR="$HOME/logs/extractor"
CLAUDE_PATH="/opt/homebrew/bin/claude"
ENV_FILE="$HOME/.config/aist/env"

# Создаём папку для логов
mkdir -p "$LOG_DIR"

DATE=$(date +%Y-%m-%d)
HOUR=$(date +%H)
LOG_FILE="$LOG_DIR/$DATE.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

notify() {
    local title="$1"
    local message="$2"
    printf 'display notification "%s" with title "%s"' "$message" "$title" | osascript 2>/dev/null || true
}

notify_telegram() {
    local scenario="$1"
    "$HOME/Github/DS-synchronizer/scripts/notify.sh" extractor "$scenario" >> "$LOG_FILE" 2>&1 || true
}

# Загрузка переменных окружения (TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID)
load_env() {
    if [ -f "$ENV_FILE" ]; then
        set -a
        source "$ENV_FILE"
        set +a
    fi
}

run_claude() {
    local command_file="$1"
    local extra_args="$2"
    local command_path="$PROMPTS_DIR/$command_file.md"

    if [ ! -f "$command_path" ]; then
        log "ERROR: Command file not found: $command_path"
        exit 1
    fi

    local prompt
    prompt=$(cat "$command_path")

    # Добавить extra args к промпту (например, путь к файлу для bulk)
    if [ -n "$extra_args" ]; then
        prompt="$prompt

## Дополнительный контекст

$extra_args"
    fi

    log "Starting process: $command_file"
    log "Command file: $command_path"

    cd "$WORKSPACE"

    # Запуск Claude Code с промптом
    "$CLAUDE_PATH" --dangerously-skip-permissions \
        --allowedTools "Read,Write,Edit,Glob,Grep,Bash" \
        -p "$prompt" \
        >> "$LOG_FILE" 2>&1

    log "Completed process: $command_file"

    # Commit + push changes (отчёты, помеченные captures)
    # NB: Claude Code внутри run_claude может уже закоммитить — проверяем staged после add
    local strategy_dir="$HOME/Github/DS-my-strategy"
    git -C "$strategy_dir" add inbox/captures.md inbox/extraction-reports/ >> "$LOG_FILE" 2>&1 || true
    if ! git -C "$strategy_dir" diff --cached --quiet 2>/dev/null; then
        git -C "$strategy_dir" commit -m "inbox-check: extraction report $DATE" >> "$LOG_FILE" 2>&1 \
            && log "Committed DS-my-strategy" \
            || log "WARN: git commit failed"
    else
        log "No new changes to commit in DS-my-strategy (Claude may have already committed)"
    fi

    if ! git -C "$strategy_dir" diff --quiet origin/main..HEAD 2>/dev/null; then
        git -C "$strategy_dir" push >> "$LOG_FILE" 2>&1 && log "Pushed DS-my-strategy" || log "WARN: git push failed"
    fi

    # macOS notification
    notify "KE: $command_file" "Процесс завершён"
}

# Проверка: уже запускался ли процесс сегодня
already_ran_today() {
    local process="$1"
    [ -f "$LOG_FILE" ] && grep -q "Completed process: $process" "$LOG_FILE"
}

# Проверка рабочих часов (пропуск ночных)
is_work_hours() {
    local hour
    hour=$(date +%H)
    [ "$hour" -ge 7 ] && [ "$hour" -le 23 ]
}

# Загружаем env
load_env

# Определяем процесс
case "$1" in
    "inbox-check")
        # Проверка рабочих часов для автоматического запуска
        if ! is_work_hours; then
            log "SKIP: inbox-check outside work hours ($HOUR:00)"
            exit 0
        fi

        # Быстрая проверка: есть ли captures в inbox (без вызова Claude)
        CAPTURES_FILE="$HOME/Github/DS-my-strategy/inbox/captures.md"
        if [ -f "$CAPTURES_FILE" ]; then
            # Ищем секции ### без метки [processed]
            PENDING=$(grep -c '^### ' "$CAPTURES_FILE" 2>/dev/null) || PENDING=0
            PROCESSED=$(grep -c '\[processed' "$CAPTURES_FILE" 2>/dev/null) || PROCESSED=0
            ACTUAL_PENDING=$((PENDING - PROCESSED))

            if [ "$ACTUAL_PENDING" -le 0 ]; then
                log "SKIP: No pending captures in inbox (total=$PENDING, processed=$PROCESSED)"
                exit 0
            fi

            log "Found $ACTUAL_PENDING pending captures in inbox"
        else
            log "SKIP: captures.md not found"
            exit 0
        fi

        run_claude "inbox-check"
        notify_telegram "inbox-check"
        ;;

    "audit")
        log "Running knowledge audit"
        run_claude "knowledge-audit"
        notify_telegram "audit"
        ;;

    "session-close")
        log "Running session-close extraction"
        run_claude "session-close"
        ;;

    "on-demand")
        log "Running on-demand extraction"
        run_claude "on-demand"
        ;;

    "bulk")
        if [ -z "$2" ]; then
            echo "Usage: $0 bulk <file-path>"
            exit 1
        fi
        log "Running bulk extraction on: $2"
        run_claude "bulk-extraction" "Файл для обработки: $2"
        ;;

    "cross-sync")
        log "Running cross-repo sync"
        run_claude "cross-repo-sync"
        ;;

    "ontology-sync")
        log "Running ontology sync"
        run_claude "ontology-sync"
        ;;

    *)
        echo "Knowledge Extractor Agent (DP.AISYS.013)"
        echo ""
        echo "Usage: $0 <process>"
        echo ""
        echo "Processes:"
        echo "  inbox-check    Headless: обработка pending captures (launchd, 3h)"
        echo "  audit          Headless: аудит Pack'ов"
        echo "  session-close  Экстракция при закрытии сессии"
        echo "  on-demand      Экстракция по запросу"
        echo "  bulk <file>    Обработка документа"
        echo "  cross-sync     Синхронизация Pack → downstream"
        echo "  ontology-sync  Синхронизация онтологий"
        exit 1
        ;;
esac

log "Done"
