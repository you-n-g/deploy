# Render pane rows with one metadata snapshot. Input 1: pane flags; stdin:
# _ai_pane_rows. Emit sort keys plus the existing ANSI picker line format.
BEGIN {
    FS = "\t"
    esc = sprintf("%c", 27)
    reset = esc "[0m"
    dim = esc "[2m"
    color_count = split(palette, colors, " ")
    split(ranked, entries, " ")
    for (i in entries) in_sequence[entries[i]] = 1
}
FILENAME != "-" {
    marked[$1] = $2 == "1"
    done[$1] = $3 == "1"
    woke[$1] = $4 == "1"
    muted[$1] = $5 == "1"
    created[$1] = $6 == "1"
    next
}
function paint(code, text) { return esc "[" code "m" text reset }
function age(seconds) {
    if (seconds < 60) return seconds "s"
    if (seconds < 3600) return int(seconds / 60) "m"
    if (seconds < 86400) return int(seconds / 3600) "h"
    return int(seconds / 86400) "d"
}
{
    visit = $1; target = $2; name = $3; pane = $4; activity = $6
    unread = $7 == "1"; running = $8 == "1"; background = $9 == "1"
    pending = $10 != "" && $10 != "0"
    path = $11; attribute = $12
    for (i = 13; i <= NF; i++) attribute = attribute "\t" $i
    input_index++

    if (target == current) {
        key = "0"
        if (pending) status = paint(35, "⏸") " "
        else if (background) status = paint(36, "➲") " "
        else if (running) status = paint(36, "▶") " "
        else if (done[pane]) status = paint(32, "✓") " "
        else status = paint(36, "▷") " "
    } else if (pending) { key = "07"; status = paint(35, "⏸") " " }
    else if (background && unread) { key = "09"; status = paint(33, "◓") " " }
    else if (background) { key = "06"; status = paint(33, "◒") " " }
    else if (running) { key = "05"; status = paint(33, "●") " " }
    else if (done[pane]) { key = "08"; status = paint(32, "✓") " " }
    else if (unread && woke[pane]) { key = "09"; status = paint(33, "☀") " " }
    else if (unread) { key = "09"; status = paint(33, "◉") " " }
    else { key = "1"; status = paint(32, "○") " " }

    session = target; sub(/:[^:]*$/, "", session)
    location = target; sub(/^.*:/, "", location)
    if (!(session in session_color)) session_color[session] = colors[(session_count++ % color_count) + 1]
    colored_target = paint(session_color[session], session) ":" location
    if (visit == activity) time_info = "[va " age(now - activity) "]"
    else time_info = "[v " age(now - visit) " | a " age(now - activity) "]"

    pending_mark = ""
    tags = target == current ? " [current]" : ""
    if (pending) pending_mark = " " paint(35, "[pending:" ($10 == "1" ? "/" : $10) "]")
    else if (background) {
        tags = tags " [background]"
        if (unread) tags = tags " " paint(33, "[unread]")
    } else if (running) tags = tags " [running]"
    else if (done[pane]) tags = tags " " paint(32, "[done]")
    else if (unread) {
        tags = tags " " paint(33, "[unread]")
        if (woke[pane]) tags = tags " " paint(33, "[woke]")
    } else tags = tags " [idle]"
    if (muted[pane]) tags = tags " [muted]"

    display_name = (pane in in_sequence) ? paint("1;91", name) : name
    if (created[pane]) display_name = display_name " " paint(36, "[agent]")
    attribute_info = attribute == "" ? "" : "  " attribute
    path_info = path == "" ? "" : "  " path
    marker = "pane " pane
    if (marked[pane]) marker = marker " marked"
    if (pane == switcher) marker = marker " switcher"
    key = key (created[pane] ? "1" : "0")
    if (preserve == "1") key = sprintf("%08d", input_index)
    printf "%s\t%s\t%s %s %s%s%s%s%s  %s%s%s%s%s  %s[%s]%s%s%s%s\n", \
        key, visit, pane, colored_target, status, display_name, dim, attribute_info, reset, \
        dim, time_info, pending_mark, tags, reset, dim, marker, reset, dim, path_info, reset
}
