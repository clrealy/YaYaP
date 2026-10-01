# about: Weather report in your terminal (via wttr.in)
cmd_weather() {
    need curl
    local loc="${*// /+}"
    curl -fsS --max-time 10 "https://wttr.in/${loc}?0" || die "couldn't reach wttr.in"
}
