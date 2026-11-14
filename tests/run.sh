#!/usr/bin/env bash
# =============================================================================
# run.sh — Corredor de pruebas sin dependencias (uso: tests/run.sh [filtro])
# =============================================================================
# Linux System Optimizer (LSO)
# Autor: Ricardo Rosero <rrosero2000@gmail.com>
# GitHub: https://github.com/rr-n4p5t3r
# Licencia: GPLv3
# =============================================================================

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LSO_BASE_DIR="$(dirname "$TESTS_DIR")"
export TESTS_DIR LSO_BASE_DIR

filter="${1:-}"
total=0 failed=0 skipped=0

for file in "$TESTS_DIR"/test_*.sh; do
    [[ -e "$file" ]] || continue
    name="$(basename "$file" .sh)"
    [[ -n "$filter" && "$name" != *"$filter"* ]] && continue
    echo "== $name"
    # Lista de funciones test_* del archivo, obtenida en un bash aparte.
    mapfile -t funcs < <(bash -c 'source "$1" >/dev/null 2>&1; declare -F | awk "\$3 ~ /^test_/ {print \$3}"' _ "$file")
    for fn in "${funcs[@]}"; do
        total=$((total + 1))
        rc=0
        # Cada prueba usa su propio TMPDIR, que se borra al terminar.
        test_tmp=$(mktemp -d)
        TMPDIR="$test_tmp" bash -c '
            set -u
            source "$TESTS_DIR/lib.sh"
            source "$1"
            # Si la prueba aborta (p. ej. una variable sin asignar con set -u),
            # bash abandona la función y sigue en el nivel superior: el
            # indicador solo queda en 1 si la prueba llegó hasta el final.
            _done=0
            _wrap() { "$1"; _done=1; }
            _wrap "$2"
            if [[ $_done -ne 1 ]]; then
                echo "    ✗ la prueba terminó de forma inesperada" >&2
                exit 99
            fi
            exit "$TEST_FAILS"
        ' _ "$file" "$fn" || rc=$?
        chmod -R u+rwX "$test_tmp" 2>/dev/null
        rm -rf "$test_tmp"
        if [[ $rc -eq 0 ]]; then
            echo "  PASS $fn"
        elif [[ $rc -eq 77 ]]; then
            skipped=$((skipped + 1)); echo "  SKIP $fn"
        else
            failed=$((failed + 1)); echo "  FAIL $fn"
        fi
    done
done

echo "Total: $total · Fallidas: $failed · Omitidas: $skipped"
[[ $failed -eq 0 && $total -gt 0 ]]
