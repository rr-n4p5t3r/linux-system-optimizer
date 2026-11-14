#!/usr/bin/env bash
# =============================================================================
# render_tui.sh — Tablero interactivo de la auditoría (lso audit)
# =============================================================================
# Linux System Optimizer (LSO)
# Autor: Ricardo Rosero <rrosero2000@gmail.com>
# GitHub: https://github.com/rr-n4p5t3r
# Licencia: GPLv3
# =============================================================================
# Bash puro: secuencias ANSI y lectura de teclas, sin dependencias.
# tui_build_frame arma el cuadro completo en memoria (TUI_FRAME, una entrada
# por fila, cada una con el ancho visible exacto de la terminal) y tui_run lo
# pinta de una sola vez para evitar parpadeo. Así el dibujo se puede probar
# sin una terminal real.
# shellcheck disable=SC2034

shopt -s extglob

# --- Estado ------------------------------------------------------------------

tui_init_state() {
    TUI_TAB=1 TUI_SEL=0 TUI_TOP=0
    TUI_FILTER_SEV="" TUI_FILTER_CAT="" TUI_SHOW_ALL=0 TUI_SEARCH=""
    TUI_DETAIL="" TUI_HELP=0 TUI_QUIT=0 TUI_MSG=""
    TUI_LIST_ROWS=10
    TUI_COLORS="${TUI_COLORS:-256}"
    TUI_FRAME=()
    _TUI_RING_KEY=""
}

# --- Colores -----------------------------------------------------------------

declare -gA TUI_C=()

_tui_colors() {
    local e=$'\033['
    TUI_C=([r]="${e}0m" [b]="${e}1m")
    if [[ "${TUI_COLORS}" -ge 256 ]]; then
        local f="${e}38;5;" g="${e}48;5;"
        TUI_C+=(
            [critical]="${f}203m" [high]="${f}211m" [medium]="${f}179m" [low]="${f}117m"
            [info]="${f}245m" [ok]="${f}114m" [dim]="${f}244m" [faint]="${f}238m"
            [border]="${f}61m" [accent]="${f}111m" [title]="${f}111m${e}1m"
            [bg_critical]="${g}203m${f}16m" [bg_high]="${g}211m${f}16m"
            [bg_medium]="${g}179m${f}16m" [bg_low]="${g}117m${f}16m" [bg_info]="${g}245m${f}16m"
            [sel]="${g}25m${e}1m" [key]="${g}238m${f}255m${e}1m" [brand]="${g}111m${f}16m${e}1m"
        )
    else
        TUI_C+=(
            [critical]="${e}31m" [high]="${e}35m" [medium]="${e}33m" [low]="${e}36m"
            [info]="${e}37m" [ok]="${e}32m" [dim]="${e}2m" [faint]="${e}2m"
            [border]="${e}34m" [accent]="${e}34m" [title]="${e}34m${e}1m"
            [bg_critical]="${e}41m${e}30m" [bg_high]="${e}45m${e}30m"
            [bg_medium]="${e}43m${e}30m" [bg_low]="${e}46m${e}30m" [bg_info]="${e}47m${e}30m"
            [sel]="${e}7m" [key]="${e}7m" [brand]="${e}44m${e}30m${e}1m"
        )
    fi
}

# Color según puntaje (1-10) o porcentaje (0-100).
_tui_score_color() { (( $1 >= 8 )) && echo ok || { (( $1 >= 5 )) && echo medium || echo critical; }; }
_tui_pct_color()   { (( $1 >= 90 )) && echo ok || { (( $1 >= 60 )) && echo medium || echo critical; }; }

# --- Utilidades de texto -----------------------------------------------------

# Ancho visible (sin secuencias ANSI) → _TL
_tui_len() {
    local s="${1//$'\033['*([0-9;])m/}"
    _TL=${#s}
}

# _tui_fit VAR TEXTO ANCHO → texto plano recortado con "…" o rellenado
_tui_fit() {
    local -n _out="$1"
    local __t="$2" __w="$3"
    if (( __w <= 0 )); then _out=""; return; fi
    if (( ${#__t} > __w )); then
        _out="${__t:0:__w-1}…"
    else
        _out="$__t"
        while (( ${#_out} < __w )); do _out+=" "; done
    fi
}

# _tui_pad VAR TEXTO_CON_COLOR ANCHO → rellena con espacios hasta el ancho visible
_tui_pad() {
    local -n _o="$1"
    local __s="$2" __w="$3"
    _tui_len "$__s"
    if (( _TL < __w )); then
        printf -v _o '%s%*s' "$__s" $((__w - _TL)) ""
    else
        _o="$__s"
    fi
}

_tui_center() { # _tui_center VAR TEXTO ANCHO (texto plano)
    local -n _c="$1"
    local __t="$2" __w="$3" __l
    (( ${#__t} > __w )) && __t="${__t:0:__w-1}…"
    __l=$(( (__w - ${#__t}) / 2 ))
    printf -v _c '%*s%s%*s' "$__l" "" "$__t" $((__w - __l - ${#__t})) ""
}

_tui_repeat() { # _tui_repeat VAR CARÁCTER N
    local -n _rp="$1"
    local __i
    _rp=""
    for ((__i = 0; __i < $3; __i++)); do _rp+="$2"; done
}

# --- Cajas -------------------------------------------------------------------

# _tui_box SALIDA ANCHO ALTO "Título" LÍNEAS… → agrega ALTO filas a SALIDA.
# Las líneas de contenido pueden traer color; se rellenan al ancho interno.
_tui_box() {
    local -n _dst="$1"
    local w="$2" h="$3" title="$4" i line top
    shift 4
    local inner=$((w - 2)) bc="${TUI_C[border]}" r="${TUI_C[r]}"
    local t=""
    [[ -n "$title" ]] && _tui_fit t " $title " $(( ${#title} + 2 > inner - 2 ? inner - 2 : ${#title} + 2 ))
    _tui_repeat top "─" $((inner - 1 - ${#t}))
    _dst+=("${bc}╭─${r}${TUI_C[title]}${t}${r}${bc}${top}╮${r}")
    for ((i = 0; i < h - 2; i++)); do
        line="${1-}"
        (( $# )) && shift
        _tui_pad line "$line" "$inner"
        _dst+=("${bc}│${r}${line}${r}${bc}│${r}")
    done
    _tui_repeat top "─" "$inner"
    _dst+=("${bc}╰${top}╯${r}")
}

# _tui_hjoin SALIDA ARREGLO… → une cajas de igual alto lado a lado (con 1 espacio)
_tui_hjoin() {
    local -n _hj="$1"
    shift
    local -n _first="$1"
    local i n=${#_first[@]} name row
    for ((i = 0; i < n; i++)); do
        row=""
        for name in "$@"; do
            local -n _col="$name"
            [[ -n "$row" ]] && row+=" "
            row+="${_col[$i]}"
            unset -n _col
        done
        _hj+=("$row")
    done
}

# --- Listas ------------------------------------------------------------------

# Elementos de la lista de la pestaña actual (IDs o categorías).
tui_items() {
    local id q="${TUI_SEARCH,,}"
    case "$TUI_TAB" in
        1) audit_sorted_ids ;;
        3) audit_categories ;;
        *)
            local mode=""
            (( TUI_SHOW_ALL )) && mode=all
            for id in $(audit_sorted_ids $mode); do
                [[ -n "$TUI_FILTER_SEV" && "${AUDIT_SEV[$id]}" != "$TUI_FILTER_SEV" ]] && continue
                [[ -n "$TUI_FILTER_CAT" && "${AUDIT_CAT[$id]}" != "$TUI_FILTER_CAT" ]] && continue
                if [[ -n "$q" ]]; then
                    local hay="${id,,} ${AUDIT_TITLE[$id],,} ${AUDIT_CAT[$id],,} ${AUDIT_DETAIL[$id],,}"
                    [[ "$hay" == *"$q"* ]] || continue
                fi
                echo "$id"
            done
            ;;
    esac
}

_tui_count() { local n=0 l; while read -r l; do [[ -n "$l" ]] && n=$((n + 1)); done < <(tui_items); echo "$n"; }

_tui_clamp() {
    local n
    n=$(_tui_count)
    (( TUI_SEL >= n )) && TUI_SEL=$((n - 1))
    (( TUI_SEL < 0 )) && TUI_SEL=0
    return 0
}

# --- Teclado -----------------------------------------------------------------

_tui_cycle() { # _tui_cycle ACTUAL OPCIONES… → siguiente (con "" como "todas")
    local cur="$1" first="" found=0 o
    shift
    for o in "" "$@"; do
        if (( found )); then echo "$o"; return; fi
        [[ "$o" == "$cur" ]] && found=1
    done
    echo "$first"
}

tui_handle_key() {
    local k="$1"
    TUI_MSG=""
    if (( TUI_HELP )); then
        [[ "$k" == q ]] && TUI_QUIT=1
        TUI_HELP=0
        return 0
    fi
    if [[ -n "$TUI_DETAIL" ]]; then
        case "$k" in
            q) TUI_QUIT=1 ;;
            ESC|ENTER|BACKSPACE|LEFT) TUI_DETAIL="" ;;
            y) _tui_copy "${AUDIT_FIX[$TUI_DETAIL]}" ;;
            '?') TUI_HELP=1 ;;
        esac
        return 0
    fi
    case "$k" in
        q) TUI_QUIT=1 ;;
        '?') TUI_HELP=1 ;;
        TAB)  TUI_TAB=$(( TUI_TAB % 3 + 1 )); TUI_SEL=0; TUI_TOP=0 ;;
        BTAB) TUI_TAB=$(( (TUI_TAB + 1) % 3 + 1 )); TUI_SEL=0; TUI_TOP=0 ;;
        1|2|3) TUI_TAB="$k"; TUI_SEL=0; TUI_TOP=0 ;;
        UP|k)   TUI_SEL=$((TUI_SEL - 1)) ;;
        DOWN|j) TUI_SEL=$((TUI_SEL + 1)) ;;
        PGUP)   TUI_SEL=$((TUI_SEL - TUI_LIST_ROWS)) ;;
        PGDN)   TUI_SEL=$((TUI_SEL + TUI_LIST_ROWS)) ;;
        HOME|g) TUI_SEL=0 ;;
        END|G)  TUI_SEL=$(_tui_count) ;;
        ENTER|RIGHT)
            local -a items
            mapfile -t items < <(tui_items)
            (( ${#items[@]} )) || return 0
            if [[ "$TUI_TAB" == 3 ]]; then
                TUI_FILTER_CAT="${items[$TUI_SEL]}"
                TUI_FILTER_SEV="" TUI_SEARCH="" TUI_SHOW_ALL=1
                TUI_TAB=2 TUI_SEL=0 TUI_TOP=0
            else
                TUI_DETAIL="${items[$TUI_SEL]}"
            fi
            ;;
        a) [[ "$TUI_TAB" == 2 ]] && { TUI_SHOW_ALL=$((1 - TUI_SHOW_ALL)); TUI_SEL=0; TUI_TOP=0; } ;;
        s) if [[ "$TUI_TAB" == 2 ]]; then
               TUI_FILTER_SEV=$(_tui_cycle "$TUI_FILTER_SEV" critical high medium low info)
               TUI_SEL=0; TUI_TOP=0
           fi ;;
        c) if [[ "$TUI_TAB" == 2 ]]; then
               local -a cats
               mapfile -t cats < <(audit_categories)
               TUI_FILTER_CAT=$(_tui_cycle "$TUI_FILTER_CAT" "${cats[@]}")
               TUI_SEL=0; TUI_TOP=0
           fi ;;
        x) TUI_FILTER_SEV="" TUI_FILTER_CAT="" TUI_SEARCH="" TUI_SHOW_ALL=0 TUI_SEL=0 TUI_TOP=0 ;;
    esac
    _tui_clamp
}

# Copia al portapapeles con OSC 52 (funciona en la mayoría de terminales,
# también por SSH).
_tui_copy() {
    local b64
    b64=$(printf '%s' "$1" | base64 | tr -d '\n')
    printf '\033]52;c;%s\a' "$b64" > /dev/tty 2>/dev/null || true
    TUI_MSG="Corrección copiada al portapapeles"
}

# --- Piezas del resumen ------------------------------------------------------

# Calcula la grilla del anillo para un tamaño (F = segmento, " " = vacío) y
# la fracción angular de cada celda (0 arriba, en sentido horario).
_tui_ring_grid() {
    local w="$1" h="$2" key="$1x$2"
    [[ "$_TUI_RING_KEY" == "$key" ]] && return 0
    mapfile -t _TUI_RING < <(awk -v W="$w" -v H="$h" 'BEGIN {
        cx = (W - 1) / 2; cy = (H - 1) / 2; rx = W / 2 - 0.5; ry = H / 2 - 0.2; pi = atan2(0, -1)
        for (r = 0; r < H; r++) {
            line = ""
            for (c = 0; c < W; c++) {
                dx = (c - cx) / rx; dy = (r - cy) / ry; d = sqrt(dx * dx + dy * dy)
                if (d >= 0.70 && d <= 1.02) {
                    a = atan2(dx, -dy); if (a < 0) a += 2 * pi
                    line = line sprintf("%d", int(a / (2 * pi) * 100)) ","
                } else line = line "-,"
            }
            print line
        }
    }')
    _TUI_RING_KEY="$key"
}

_TUI_FONT=(
    "███|█ █|█ █|█ █|███" "██ | █ | █ | █ |███" "███|  █|███|█  |███" "███|  █|███|  █|███"
    "█ █|█ █|███|  █|  █" "███|█  |███|  █|███" "███|█  |███|█ █|███" "███|  █|  █|  █|  █"
    "███|█ █|███|█ █|███" "███|█ █|███|  █|███"
)

# Filas de texto plano del número grande (5 filas).
_tui_big_number() {
    local n="$1" row d i glyph out
    for ((row = 0; row < 5; row++)); do
        out=""
        for ((i = 0; i < ${#n}; i++)); do
            d="${n:i:1}"
            IFS='|' read -r -a glyph <<< "${_TUI_FONT[$d]}"
            [[ -n "$out" ]] && out+=" "
            out+="${glyph[$row]}"
        done
        echo "$out"
    done
}

_tui_verdict() {
    local s="$1"
    if   (( s >= 9 )); then echo "Excelente: muy bien protegido"
    elif (( s >= 7 )); then echo "Bueno: quedan detalles"
    elif (( s >= 5 )); then echo "Mejorable: hay brechas relevantes"
    elif (( s >= 3 )); then echo "Débil: riesgos serios"
    else echo "Crítico: actúa cuanto antes"
    fi
}

# Contenido de la caja de puntaje → arreglo _TUI_SCORE (inner w x h)
_tui_score_panel() {
    local w="$1" h="$2" ringh=$(( $2 - 3 )) score="$AUDIT_SCORE"
    local col="${TUI_C[$(_tui_score_color "$score")]}" faint="${TUI_C[faint]}" r="${TUI_C[r]}"
    local -a big
    mapfile -t big < <(_tui_big_number "$score")
    _tui_ring_grid "$w" "$ringh"
    local fill=$(( score * 10 )) row c cells line bigw=${#big[0]} bigtop cx0
    bigtop=$(( (ringh - 6) / 2 ))
    cx0=$(( (w - bigw) / 2 ))
    _TUI_SCORE=()
    for ((row = 0; row < ringh; row++)); do
        IFS=',' read -r -a cells <<< "${_TUI_RING[$row]}"
        line=""
        for ((c = 0; c < w; c++)); do
            # Número grande y "de 10" en el centro del anillo.
            if (( row >= bigtop && row < bigtop + 5 && c >= cx0 && c < cx0 + bigw )); then
                local ch="${big[$((row - bigtop))]:$((c - cx0)):1}"
                [[ "$ch" == " " ]] && line+=" " || line+="${col}${TUI_C[b]}${ch}${r}"
                continue
            fi
            if (( row == bigtop + 5 && c == (w - 5) / 2 )); then
                line+="${TUI_C[dim]}de 10${r}"
                c=$((c + 4))
                continue
            fi
            if [[ "${cells[$c]}" == "-" ]]; then
                line+=" "
            elif (( cells[c] < fill )); then
                line+="${col}⣿${r}"
            else
                line+="${faint}⣿${r}"
            fi
        done
        _TUI_SCORE+=("$line")
    done
    local v cap=""
    _tui_center v "$(_tui_verdict "$score")" "$w"
    _TUI_SCORE+=("" "${col}${TUI_C[b]}${v}${r}")
    if [[ -n "${AUDIT_CAP:-}" ]]; then
        _tui_center cap "${AUDIT_CAP_REASON}" "$w"
    else
        _tui_center cap "Base ${AUDIT_SCORE_BASE}/10 · ${AUDIT_PERCENT} % aprobado" "$w"
    fi
    _TUI_SCORE+=("${TUI_C[medium]}${cap}${r}")
}

# Barras verticales por gravedad → _TUI_BARS (inner w x h)
_tui_bars_panel() {
    local w="$1" h="$2" r="${TUI_C[r]}"
    local -a sev=(critical high medium low) lab=("CRÍT" "ALTO" "MEDIO" "BAJO") cnt hgt
    local max=1 i area=$(( h - 3 )) bw=5 gap left row line s n
    for i in 0 1 2 3; do
        cnt[i]=${AUDIT_COUNT[${sev[i]}]:-0}
        (( cnt[i] > max )) && max=${cnt[i]}
    done
    for i in 0 1 2 3; do
        n=${cnt[i]}
        if (( n == 0 )); then hgt[i]=0; else hgt[i]=$(( (n * (area - 1) + max - 1) / max )); (( hgt[i] < 1 )) && hgt[i]=1; fi
    done
    gap=$(( (w - 4 * bw) / 5 ))
    (( gap < 1 )) && gap=1
    left=$(( (w - 4 * bw - 3 * gap) / 2 ))
    _TUI_BARS=()
    for ((row = 0; row < area; row++)); do
        line=$(printf '%*s' "$left" "")
        for i in 0 1 2 3; do
            (( i )) && line+=$(printf '%*s' "$gap" "")
            local fromtop=$(( area - row ))
            if (( fromtop <= hgt[i] )); then
                line+="${TUI_C[${sev[i]}]}█████${r}"
            elif (( fromtop == hgt[i] + 1 )); then
                local num
                _tui_center num "${cnt[i]}" "$bw"
                line+="${TUI_C[${sev[i]}]}${TUI_C[b]}${num}${r}"
            else
                line+="     "
            fi
        done
        _TUI_BARS+=("$line")
    done
    line=$(printf '%*s' "$left" "")
    for i in 0 1 2 3; do
        (( i )) && line+=$(printf '%*s' "$gap" "")
        _tui_center s "${lab[i]}" "$bw"
        line+="${TUI_C[${sev[i]}]}${s}${r}"
    done
    _TUI_BARS+=("$line")
    local summary
    _tui_center summary "✓ ${AUDIT_COUNT[pass]} · ? ${AUDIT_COUNT[skip]} · ≈ ${AUDIT_COUNT[waived]} · – ${AUDIT_COUNT[na]}" "$w"
    _TUI_BARS+=("${TUI_C[dim]}${summary}${r}")
}

# Barra horizontal de porcentaje: _tui_hbar VAR PCT ANCHO
_tui_hbar() {
    local -n _hb="$1"
    local pct="$2" w="$3" on off col
    if [[ "$pct" == "-" ]]; then
        _tui_repeat off "─" "$w"
        _hb="${TUI_C[faint]}${off}${TUI_C[r]}"
        return
    fi
    on=$(( pct * w / 100 ))
    col="${TUI_C[$(_tui_pct_color "$pct")]}"
    local a b
    _tui_repeat a "━" "$on"
    _tui_repeat b "─" $((w - on))
    _hb="${col}${a}${TUI_C[faint]}${b}${TUI_C[r]}"
}

# Filas de categorías → _TUI_CATS (inner w)
_tui_cats_panel() {
    local w="$1" cat pct open name bar p o
    local bw=$(( w - 25 ))
    (( bw < 4 )) && bw=4
    _TUI_CATS=()
    while read -r cat; do
        [[ -z "$cat" ]] && continue
        pct=$(audit_category_percent "$cat")
        open=$(audit_category_open "$cat")
        _tui_fit name "$cat " 12
        _tui_hbar bar "$pct" "$bw"
        if [[ "$pct" == "-" ]]; then p="   –   "; else printf -v p '%4s %% ' "$pct"; fi
        if (( open > 0 )); then o="${TUI_C[critical]}✖ $(printf '%-3s' "$open")${TUI_C[r]}"; else o="     "; fi
        local pc="${TUI_C[dim]}"
        [[ "$pct" != "-" ]] && pc="${TUI_C[$(_tui_pct_color "$pct")]}"
        _TUI_CATS+=(" ${TUI_C[accent]}${TUI_C[b]}${name}${TUI_C[r]}${bar}${pc}${p}${TUI_C[r]}${o}")
    done < <(audit_categories)
}

# --- Filas de la lista de hallazgos ------------------------------------------

_tui_status_icon() {
    case "$1" in
        FAIL) echo "${TUI_C[critical]}✖${TUI_C[r]}" ;;
        WARN) echo "${TUI_C[medium]}▲${TUI_C[r]}" ;;
        PASS) echo "${TUI_C[ok]}✓${TUI_C[r]}" ;;
        SKIP) echo "${TUI_C[dim]}?${TUI_C[r]}" ;;
        NA)   echo "${TUI_C[dim]}–${TUI_C[r]}" ;;
        *)    echo "${TUI_C[dim]}≈${TUI_C[r]}" ;;
    esac
}

# _tui_finding_row VAR ID ANCHO SELECCIONADA
_tui_finding_row() {
    local -n _row="$1"
    local id="$2" w="$3" sel="$4" sev badge title cat tw
    sev="${AUDIT_SEV[$id]}"
    _tui_fit badge " $(audit_sev_label "$sev")" 9
    _tui_fit cat "${AUDIT_CAT[$id]}" 12
    tw=$(( w - 3 - 9 - 1 - 9 - 12 - 1 ))
    _tui_fit title "${AUDIT_TITLE[$id]}" "$tw"
    local idf
    _tui_fit idf "$id" 9
    local icon
    icon=$(_tui_status_icon "${AUDIT_STATUS[$id]}")
    if [[ "$sel" == 1 ]]; then
        _row="${TUI_C[sel]}▌${TUI_C[r]}${icon}${TUI_C[sel]} ${TUI_C[r]}${TUI_C[bg_$sev]}${badge}${TUI_C[r]}${TUI_C[sel]} ${idf}${title} ${cat}${TUI_C[r]}"
    else
        _row=" ${icon} ${TUI_C[bg_$sev]}${badge}${TUI_C[r]} ${TUI_C[dim]}${idf}${TUI_C[r]}${title} ${TUI_C[dim]}${cat}${TUI_C[r]}"
    fi
}

# Ajusta TUI_TOP para que la selección quede visible en N filas.
_tui_scroll() {
    local rows="$1"
    TUI_LIST_ROWS="$rows"
    (( TUI_SEL < TUI_TOP )) && TUI_TOP=$TUI_SEL
    (( TUI_SEL >= TUI_TOP + rows )) && TUI_TOP=$((TUI_SEL - rows + 1))
    (( TUI_TOP < 0 )) && TUI_TOP=0
    return 0
}

# _tui_list_lines ARREGLO_SALIDA ANCHO FILAS → filas de la lista actual
_tui_list_lines() {
    local -n _ll="$1"
    local w="$2" rows="$3" i row
    local -a items
    mapfile -t items < <(tui_items)
    _tui_scroll "$rows"
    _ll=()
    if (( ${#items[@]} == 0 )); then
        local msg
        _tui_center msg "Sin hallazgos para mostrar" "$w"
        _ll+=("" "${TUI_C[ok]}${msg}${TUI_C[r]}")
        return
    fi
    for ((i = TUI_TOP; i < TUI_TOP + rows && i < ${#items[@]}; i++)); do
        _tui_finding_row row "${items[$i]}" "$w" $(( i == TUI_SEL ? 1 : 0 ))
        _ll+=("$row")
    done
}

# --- Pestañas ----------------------------------------------------------------

_tui_tab_summary() {
    local -n _out="$1"
    local W="$2" CH="$3"
    local topH=15 sw=37 bw=28 cw
    (( CH - topH < 6 )) && topH=$(( CH - 6 ))
    cw=$(( W - sw - bw - 2 ))
    _tui_score_panel $((sw - 2)) $((topH - 2))
    _tui_bars_panel $((bw - 2)) $((topH - 2))
    _tui_cats_panel $((cw - 2))
    local -a b1=() b2=() b3=() list=()
    _tui_box b1 "$sw" "$topH" "Puntaje" "${_TUI_SCORE[@]}"
    _tui_box b2 "$bw" "$topH" "Abiertos por gravedad" "${_TUI_BARS[@]}"
    _tui_box b3 "$cw" "$topH" "Categorías" "" "${_TUI_CATS[@]}"
    _tui_hjoin _out b1 b2 b3
    local lh=$(( CH - topH ))
    _tui_list_lines list $((W - 2)) $((lh - 2))
    local -a b4=()
    _tui_box b4 "$W" "$lh" "Lo más urgente" "${list[@]}"
    _out+=("${b4[@]}")
}

_tui_tab_findings() {
    local -n _out="$1"
    local W="$2" CH="$3" f sevl catl
    sevl="${TUI_FILTER_SEV:-todas}"
    [[ -n "$TUI_FILTER_SEV" ]] && sevl=$(audit_sev_label "$TUI_FILTER_SEV")
    catl="${TUI_FILTER_CAT:-todas}"
    local estado="abiertos"
    (( TUI_SHOW_ALL )) && estado="todos"
    f=" Estado: ${estado}   Gravedad: ${sevl}   Categoría: ${catl}"
    [[ -n "$TUI_SEARCH" ]] && f+="   Buscar: ${TUI_SEARCH}"
    f+="   ($(_tui_count) resultados)"
    _tui_fit f "$f" "$W"
    _out+=("${TUI_C[dim]}${f}${TUI_C[r]}")
    local -a list=() box=()
    _tui_list_lines list $((W - 2)) $((CH - 3))
    _tui_box box "$W" $((CH - 1)) "Hallazgos" "${list[@]}"
    _out+=("${box[@]}")
}

_tui_tab_categories() {
    local -n _out="$1"
    local W="$2" CH="$3" i cat pct open pass skip na line name bar p
    local inner=$((W - 2)) bw
    bw=$(( inner - 64 ))
    (( bw < 6 )) && bw=6
    local -a cats rows=() box=()
    mapfile -t cats < <(audit_categories)
    _tui_scroll $((CH - 4))
    local hdr
    printf -v hdr '   %-12s%-*s %6s  %8s  %9s  %8s  %9s' "Categoría" "$bw" "" "%" "Abiertos" "Aprobadas" "No eval." "No aplica"
    _tui_fit hdr "$hdr" "$inner"
    rows+=("${TUI_C[dim]}${hdr}${TUI_C[r]}")
    for ((i = TUI_TOP; i < ${#cats[@]} && i < TUI_TOP + CH - 4; i++)); do
        cat="${cats[$i]}"
        pct=$(audit_category_percent "$cat")
        open=$(audit_category_open "$cat")
        pass=0 skip=0 na=0
        local id
        for id in "${AUDIT_IDS[@]}"; do
            [[ "${AUDIT_CAT[$id]}" == "$cat" ]] || continue
            case "${AUDIT_STATUS[$id]:-}" in PASS) pass=$((pass + 1)) ;; SKIP) skip=$((skip + 1)) ;; NA) na=$((na + 1)) ;; esac
        done
        _tui_fit name "$cat" 12
        _tui_hbar bar "$pct" "$bw"
        [[ "$pct" == "-" ]] && p="     –" || printf -v p '%4s %%' "$pct"
        local nums
        printf -v nums '  %8s  %9s  %8s  %9s' "$open" "$pass" "$skip" "$na"
        if (( i == TUI_SEL )); then
            line="${TUI_C[sel]}▌  ${name}${TUI_C[r]}${bar}${TUI_C[sel]} ${p}${nums}${TUI_C[r]}"
        else
            line="   ${TUI_C[accent]}${TUI_C[b]}${name}${TUI_C[r]}${bar} ${p}${nums}"
        fi
        rows+=("$line")
    done
    _tui_box box "$W" "$CH" "Categorías" "${rows[@]}"
    _out+=("${box[@]}")
}

# --- Superposiciones ---------------------------------------------------------

# _tui_wrap TEXTO ANCHO → líneas
_tui_wrap() { fold -s -w "$2" <<< "$1" | sed 's/[[:space:]]*$//'; }

_tui_detail() {
    local -n _out="$1"
    local W="$2" CH="$3" id="$TUI_DETAIL" inner=$(( $2 - 4 ))
    local sev="${AUDIT_SEV[$id]}" st="${AUDIT_STATUS[$id]}" stl l
    case "$st" in
        FAIL) stl="Falla" ;; WARN) stl="Advertencia" ;; PASS) stl="Aprobada" ;;
        SKIP) stl="No evaluable" ;; NA) stl="No aplica" ;; *) stl="Exceptuada" ;;
    esac
    local -a rows=("" "  ${TUI_C[bg_$sev]} $(audit_sev_label "$sev") ${TUI_C[r]}  $(_tui_status_icon "$st") ${stl}   ${TUI_C[dim]}Categoría:${TUI_C[r]} ${AUDIT_CAT[$id]}")
    if [[ -n "${AUDIT_ADJ[$id]}" ]]; then
        rows+=("  ${TUI_C[dim]}Gravedad ajustada por el perfil (${AUDIT_ADJ[$id]}); original: $(audit_sev_label "${AUDIT_BASE_SEV[$id]}")${TUI_C[r]}")
    fi
    rows+=("" "  ${TUI_C[b]}Detalle${TUI_C[r]}")
    while IFS= read -r l; do rows+=("  $l"); done < <(_tui_wrap "${AUDIT_DETAIL[$id]:-—}" "$inner")
    rows+=("" "  ${TUI_C[b]}Corrección${TUI_C[r]}")
    while IFS= read -r l; do rows+=("  ${TUI_C[ok]}$l${TUI_C[r]}"); done < <(_tui_wrap "${AUDIT_FIX[$id]}" "$inner")
    # No pasar del alto disponible.
    (( ${#rows[@]} > CH - 2 )) && rows=("${rows[@]:0:CH-2}")
    local title
    _tui_fit title "$id · ${AUDIT_TITLE[$id]}" $(( W - 8 ))
    title="${title%%+( )}"
    _tui_box _out "$W" "$CH" "$title" "${rows[@]}"
}

_tui_help() {
    local -n _out="$1"
    local W="$2" CH="$3"
    local -a rows=(
        ""
        "  ${TUI_C[b]}Navegación${TUI_C[r]}"
        "    ↑ ↓  j k        mover la selección"
        "    RePág AvPág     página anterior / siguiente"
        "    Inicio Fin g G  primero / último"
        "    Tab  1 2 3      cambiar de pestaña"
        "    Enter           ver detalle (en Categorías: ver sus hallazgos)"
        "    Esc             volver"
        ""
        "  ${TUI_C[b]}Hallazgos${TUI_C[r]}"
        "    a               abiertos / todos"
        "    s               filtrar por gravedad"
        "    c               filtrar por categoría"
        "    /               buscar"
        "    x               quitar filtros"
        "    y               (en el detalle) copiar la corrección"
        ""
        "    q               salir"
        ""
        "  ${TUI_C[dim]}Pulsa cualquier tecla para cerrar esta ayuda.${TUI_C[r]}"
    )
    (( ${#rows[@]} > CH - 2 )) && rows=("${rows[@]:0:CH-2}")
    _tui_box _out "$W" "$CH" "Atajos" "${rows[@]}"
}

# --- Cuadro completo ---------------------------------------------------------

_tui_header() {
    local W="$1" left right src="detectado" l r
    [[ "${AUDIT_PROFILE_SOURCE:-}" == chosen ]] && src="elegido"
    left=" ${AUDIT_HOST:-} · ${AUDIT_DISTRO:-} · ⬢ ${AUDIT_PROFILE_LABEL:-} (${src})"
    right="v${AUDIT_VERSION:-} · ${AUDIT_DURATION:-0} s "
    _tui_fit l "$left" $(( W - 14 - ${#right} ))
    _TUI_HDR="${TUI_C[brand]} ◆ lso audit ${TUI_C[r]}${TUI_C[accent]}${l}${TUI_C[r]} ${TUI_C[dim]}${right}${TUI_C[r]}"
}

_tui_tabs() {
    local W="$1" i t line="" n_open n_cat
    n_open=$(( AUDIT_COUNT[fail] + AUDIT_COUNT[warn] ))
    n_cat=$(audit_categories | wc -l)
    local -a names=("1 Resumen" "2 Hallazgos ${n_open}" "3 Categorías ${n_cat}")
    for i in 0 1 2; do
        t="${names[i]}"
        (( i )) && line+="${TUI_C[faint]} │ ${TUI_C[r]}"
        if (( TUI_TAB == i + 1 )); then
            line+="${TUI_C[accent]}${TUI_C[b]}${t}${TUI_C[r]}"
        else
            line+="${TUI_C[dim]}${t}${TUI_C[r]}"
        fi
    done
    _TUI_TABS=" $line"
}

_tui_footer() {
    local W="$1" k="${TUI_C[key]}" r="${TUI_C[r]}" d="${TUI_C[dim]}" f
    if [[ -n "$TUI_MSG" ]]; then
        _tui_fit f " $TUI_MSG" "$W"
        _TUI_FOOT="${TUI_C[ok]}${f}${r}"
        return
    fi
    if [[ -n "$TUI_DETAIL" ]]; then
        f=" ${k} Esc ${r}${d} volver  ${r}${k} y ${r}${d} copiar corrección  ${r}${k} ? ${r}${d} ayuda  ${r}${k} q ${r}${d} salir${r}"
    else
        f=" ${k} ↑↓ ${r}${d} mover  ${r}${k} Tab ${r}${d} pestaña  ${r}${k} Enter ${r}${d} abrir  ${r}"
        [[ "$TUI_TAB" == 2 ]] && f+="${k} a ${r}${d} todos  ${r}${k} s ${r}${d} gravedad  ${r}${k} c ${r}${d} categoría  ${r}${k} / ${r}${d} buscar  ${r}"
        f+="${k} ? ${r}${d} ayuda  ${r}${k} q ${r}${d} salir${r}"
    fi
    _tui_len "$f"
    if (( _TL > W )); then
        _tui_fit f " ↑↓ mover · Tab pestaña · Enter abrir · ? ayuda · q salir" "$W"
        f="${d}${f}${r}"
    fi
    _TUI_FOOT="$f"
}

# tui_build_frame ANCHO ALTO → TUI_FRAME (ALTO filas de ANCHO visible exacto)
tui_build_frame() {
    local W="$1" H="$2" i
    _tui_colors
    TUI_FRAME=()
    if (( W < 100 || H < 30 )); then
        local -a msg=("Terminal muy pequeña (${W}×${H})."
            "El tablero necesita al menos 100×30."
            "Agranda la ventana, o usa: lso audit --plain"
            "" "q para salir")
        local top=$(( (H - ${#msg[@]}) / 2 )) line
        for ((i = 0; i < H; i++)); do
            line=""
            if (( i >= top && i < top + ${#msg[@]} )); then
                _tui_center line "${msg[i - top]}" "$W"
            else
                printf -v line '%*s' "$W" ""
            fi
            TUI_FRAME+=("$line")
        done
        return 0
    fi
    _tui_header "$W"
    _tui_tabs "$W"
    _tui_footer "$W"
    local -a body=()
    local CH=$(( H - 3 ))
    if (( TUI_HELP )); then
        _tui_help body "$W" "$CH"
    elif [[ -n "$TUI_DETAIL" ]]; then
        _tui_detail body "$W" "$CH"
    else
        case "$TUI_TAB" in
            1) _tui_tab_summary body "$W" "$CH" ;;
            2) _tui_tab_findings body "$W" "$CH" ;;
            3) _tui_tab_categories body "$W" "$CH" ;;
        esac
    fi
    local line
    for line in "$_TUI_HDR" "$_TUI_TABS" "${body[@]:0:CH}" "$_TUI_FOOT"; do
        _tui_pad line "$line" "$W"
        TUI_FRAME+=("$line")
    done
    while (( ${#TUI_FRAME[@]} < H )); do
        printf -v line '%*s' "$W" ""
        TUI_FRAME+=("$line")
    done
    return 0
}

# --- Bucle interactivo -------------------------------------------------------

_tui_read_key() {
    local k rest
    IFS= read -rsn1 -t 1 k < /dev/tty || { _TUI_KEY=""; return 1; }
    case "$k" in
        $'\033')
            IFS= read -rsn2 -t 0.02 rest < /dev/tty || rest=""
            case "$rest" in
                '[A'|OA) _TUI_KEY=UP ;; '[B'|OB) _TUI_KEY=DOWN ;;
                '[C'|OC) _TUI_KEY=RIGHT ;; '[D'|OD) _TUI_KEY=LEFT ;;
                '[H'|OH) _TUI_KEY=HOME ;; '[F'|OF) _TUI_KEY=END ;;
                '[Z') _TUI_KEY=BTAB ;;
                '[5') read -rsn1 -t 0.02 _ < /dev/tty; _TUI_KEY=PGUP ;;
                '[6') read -rsn1 -t 0.02 _ < /dev/tty; _TUI_KEY=PGDN ;;
                '[1'|'[4') read -rsn1 -t 0.02 rest < /dev/tty
                           [[ "$rest" == "~" ]] && _TUI_KEY=HOME || _TUI_KEY="" ;;
                '') _TUI_KEY=ESC ;;
                *) _TUI_KEY="" ;;
            esac
            ;;
        '') _TUI_KEY=ENTER ;;
        $'\t') _TUI_KEY=TAB ;;
        $'\177'|$'\b') _TUI_KEY=BACKSPACE ;;
        *) _TUI_KEY="$k" ;;
    esac
    return 0
}

_tui_size() {
    local s
    s=$(stty size < /dev/tty 2>/dev/null) || s="$(tput lines) $(tput cols)"
    TUI_H="${s% *}"
    TUI_W="${s#* }"
}

_tui_draw() {
    local out
    _tui_size
    tui_build_frame "$TUI_W" "$TUI_H"
    # Cada fila se termina con "borrar hasta el final" para no dejar restos.
    out=$(IFS=$'\n'; printf '%s' "${TUI_FRAME[*]}")
    printf '\033[H%s\033[J' "${out//$'\n'/$'\033[K\n'}" > /dev/tty
}

_TUI_STTY=""
_tui_restore() {
    printf '\033[?25h\033[?1049l' > /dev/tty 2>/dev/null
    [[ -n "$_TUI_STTY" ]] && stty "$_TUI_STTY" < /dev/tty 2>/dev/null
    _TUI_STTY=""
}

_tui_search_prompt() {
    local q
    printf '\033[%d;1H\033[K\033[?25h Buscar: ' "$TUI_H" > /dev/tty
    stty "$_TUI_STTY" < /dev/tty 2>/dev/null
    IFS= read -r q < /dev/tty || q=""
    stty -echo -icanon < /dev/tty 2>/dev/null
    printf '\033[?25l' > /dev/tty
    TUI_SEARCH="$q" TUI_SEL=0 TUI_TOP=0
}

# tui_supported → 0 si la terminal permite el tablero
tui_supported() {
    [[ -t 1 && -t 0 ]] || return 1
    [[ -r /dev/tty ]] || return 1
    local cm
    cm=$(locale charmap 2>/dev/null)
    [[ "$cm" == UTF-8 ]] || return 1
    _tui_size
    (( TUI_W >= 100 && TUI_H >= 30 ))
}

tui_run() {
    tui_init_state
    local c
    c=$(tput colors 2>/dev/null || echo 8)
    TUI_COLORS="${c:-8}"
    [[ "${COLORTERM:-}" == *truecolor* || "${COLORTERM:-}" == *24bit* ]] && TUI_COLORS=256
    _TUI_STTY=$(stty -g < /dev/tty 2>/dev/null)
    trap '_tui_restore' EXIT
    trap '_tui_restore; exit 130' INT TERM
    trap 'TUI_RESIZED=1' WINCH
    stty -echo -icanon < /dev/tty 2>/dev/null
    printf '\033[?1049h\033[?25l\033[2J' > /dev/tty
    _tui_draw
    while (( ! TUI_QUIT )); do
        if _tui_read_key; then
            if [[ "$_TUI_KEY" == / && "$TUI_TAB" != 2 ]]; then
                TUI_TAB=2
            fi
            if [[ "$_TUI_KEY" == / && -z "$TUI_DETAIL" && "$TUI_HELP" == 0 ]]; then
                _tui_search_prompt
            elif [[ -n "$_TUI_KEY" ]]; then
                tui_handle_key "$_TUI_KEY"
            fi
            _tui_draw
        elif (( ${TUI_RESIZED:-0} )); then
            TUI_RESIZED=0
            printf '\033[2J' > /dev/tty
            _tui_draw
        fi
    done
    _tui_restore
    trap - EXIT INT TERM WINCH
}
