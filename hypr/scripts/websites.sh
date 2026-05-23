#!/bin/bash
for b in zen-browser firefox brave librewolf chromium; do
    if command -v "$b" &>/dev/null; then
        BROWSER="$b"
        break
    fi
done

run_sites_menu() {
    pkill -x rofi 2>/dev/null
    sleep 0.1

    rofi_menu() {
        local lines="${2:-10}"
        rofi -dmenu -i \
            -theme-str 'window { width: 520px; }' \
            -theme-str 'mainbox { padding: 0px; spacing: 0px; }' \
            -theme-str 'inputbar { padding: 8px; }' \
            -theme-str "listview { columns: 1; lines: ${lines}; fixed-height: false; dynamic: true; spacing: 0px; }" \
            -theme-str 'element { padding: 4px 8px; }' \
            -p "$1"
    }

    open_all() {
        for url in "$@"; do
            "$BROWSER" "$url" &
        done
    }

    local ai_urls=(
        "https://chatgpt.com"
        "https://claude.ai"
        "https://duck.ai/"
        "https://kimi.com"
        "https://grok.com"
        "https://gemini.google.com/"
        "https://aistudio.google.com/"
        "https://chat.deepseek.com/"
        "https://chat.qwen.ai/"
    )

    local anime_urls=(
        "https://animekai.to/home"
        "https://animepahe.si/"
        "https://aniwatchtv.to/home"
        "https://animeyy.com"
        "https://www.miruro.tv/"
        "https://kuudere.ru"
        "https://kaa.lt/"
    )

    local web_urls=(
        "https://reddit.com"
        "https://letterboxd.com"
        "https://www.privacyguides.org/en/tools/"
        "https://news.ycombinator.com/"
        "https://lobste.rs/"
        "https://www.techmeme.com/"
"https://apt.izzysoft.de/fdroid/"
        "https://f-droid.org/"
        "https://danbooru.donmai.us/"
        "https://www.deepl.com/en"
        "https://mail.google.com"
        "https://github.com"
        "https://wikipedia.org"
        "https://mail.proton.me/u/0/inbox"
        "https://pass.proton.me/u/0"
    )

    local streaming_urls=(
        "https://www.cineby.sc/"
        "https://www.bitcine.net/"
        "https://www.fmovies.gd/"
        "https://xprime.su/"
        "https://67movies.net"
        "https://cinegram.net"
        "https://popcornmovies.org/home"
        "https://shuttletv.su"
    )

    local favorites_urls=(
        "https://wallhaven.cc/toplist"
        "https://youtube.com"
        "https://music.youtube.com"
"https://last.fm"
        "https://pinterest.com"
        "https://fmhy.net/beginners-guide"
        "https://x.com"
    )

    open_site_choice() {
        case "$1" in
            *ChatGPT) "$BROWSER" "https://chatgpt.com" ;;
            *Claude) "$BROWSER" "https://claude.ai" ;;
            *DuckAI) "$BROWSER" "https://duck.ai/" ;;
            *Kimi) "$BROWSER" "https://kimi.com" ;;
            *Grok) "$BROWSER" "https://grok.com" ;;
            *Gemini) "$BROWSER" "https://gemini.google.com/" ;;
            *AI\ Studio) "$BROWSER" "https://aistudio.google.com/" ;;
            *DeepSeek) "$BROWSER" "https://chat.deepseek.com/" ;;
            *Qwen) "$BROWSER" "https://chat.qwen.ai/" ;;
            *AnimeKai) "$BROWSER" "https://animekai.to/home" ;;
            *AnimePahe) "$BROWSER" "https://animepahe.si/" ;;
            *AniWatchTV) "$BROWSER" "https://aniwatchtv.to/home" ;;
            *AnimeYY) "$BROWSER" "https://animeyy.com" ;;
            *Miruro) "$BROWSER" "https://www.miruro.tv/" ;;
            *Kuudere) "$BROWSER" "https://kuudere.ru" ;;
            *Kaa) "$BROWSER" "https://kaa.lt/" ;;
            *Twitter) "$BROWSER" "https://x.com" ;;
            *Reddit) "$BROWSER" "https://reddit.com" ;;
            *Letterboxd) "$BROWSER" "https://letterboxd.com" ;;
            *Pinterest) "$BROWSER" "https://pinterest.com" ;;
            *Last.fm) "$BROWSER" "https://last.fm" ;;
            *Privacy\ Guides) "$BROWSER" "https://www.privacyguides.org/en/tools/" ;;
            *Hacker\ News) "$BROWSER" "https://news.ycombinator.com/" ;;
            *Lobsters) "$BROWSER" "https://lobste.rs/" ;;
            *Techmeme) "$BROWSER" "https://www.techmeme.com/" ;;
            *FMHY) "$BROWSER" "https://fmhy.net/beginners-guide" ;;
            *IzzyOnDroid) "$BROWSER" "https://apt.izzysoft.de/fdroid/" ;;
            *FDroid) "$BROWSER" "https://f-droid.org/" ;;
            *YouTube) "$BROWSER" "https://youtube.com" ;;
            *YouTube\ Music) "$BROWSER" "https://music.youtube.com" ;;
            *Danbooru) "$BROWSER" "https://danbooru.donmai.us/" ;;
            *Wallhaven) "$BROWSER" "https://wallhaven.cc/toplist" ;;
            *DeepL) "$BROWSER" "https://www.deepl.com/en" ;;
            *Gmail) "$BROWSER" "https://mail.google.com" ;;
            *GitHub) "$BROWSER" "https://github.com" ;;
            *Wikipedia) "$BROWSER" "https://wikipedia.org" ;;
            *Proton\ Mail) "$BROWSER" "https://mail.proton.me/u/0/inbox" ;;
            *Proton\ Pass) "$BROWSER" "https://pass.proton.me/u/0" ;;
            *X.com) "$BROWSER" "https://x.com" ;;
            *Cineby) "$BROWSER" "https://www.cineby.sc/" ;;
            *Bitcine) "$BROWSER" "https://www.bitcine.net/" ;;
            *Fmovies) "$BROWSER" "https://www.fmovies.gd/" ;;
            *XPrime) "$BROWSER" "https://xprime.su/" ;;
            *67Movies) "$BROWSER" "https://67movies.net" ;;
            *Cinegram) "$BROWSER" "https://cinegram.net" ;;
            *PopcornMovies) "$BROWSER" "https://popcornmovies.org/home" ;;
            *ShuttleTV) "$BROWSER" "https://shuttletv.su" ;;
            *aria2) zeditor "$HOME/.config/aria2" ;;
            *gallery-dl) zeditor "$HOME/.config/gallery-dl" ;;
            *kitty) zeditor "$HOME/.config/kitty" ;;
            *waybar) zeditor "$HOME/.config/waybar" ;;
            *rofi) zeditor "$HOME/.config/rofi" ;;
            *hypr) zeditor "$HOME/.config/hypr" ;;
            *mpv) zeditor "$HOME/.config/mpv" ;;
            *swayimg) zeditor "$HOME/.config/swayimg" ;;
            *yt-dlp) zeditor "$HOME/.config/yt-dlp" ;;
            *swaync) zeditor "$HOME/.config/swaync" ;;
            *zathura) zeditor "$HOME/.config/zathura" ;;
            *fish) zeditor "$HOME/.config/fish" ;;
        esac
    }

    local anime_entries='❀  AnimeKai
❀  AnimePahe
❀  AniWatchTV
❀  AnimeYY
❀  Miruro
❀  Kuudere
❀  Kaa'
    local anime_count
    anime_count=$(printf '%s\n' "$anime_entries" | wc -l)

    local ai_entries='❀  ChatGPT
❀  Claude
❀  DuckAI
❀  Kimi
❀  Grok
❀  Gemini
❀  AI Studio
❀  DeepSeek
❀  Qwen'
    local ai_count
    ai_count=$(printf '%s\n' "$ai_entries" | wc -l)

    local web_entries='❀  Reddit
❀  Letterboxd
❀  Privacy Guides
❀  Hacker News
❀  Lobsters
❀  Techmeme
❀  IzzyOnDroid
❀  FDroid
❀  Danbooru
❀  DeepL
❀  Gmail
❀  GitHub
❀  Wikipedia
❀  Proton Mail
❀  Proton Pass'
    local web_count
    web_count=$(printf '%s\n' "$web_entries" | wc -l)

    local streaming_entries='❀  Cineby
❀  Bitcine
❀  Fmovies
❀  XPrime
❀  67Movies
❀  Cinegram
❀  PopcornMovies
❀  ShuttleTV'
    local streaming_count
    streaming_count=$(printf '%s\n' "$streaming_entries" | wc -l)

    local favorites_entries='❀  Wallhaven
❀  YouTube
❀  YouTube Music
❀  Last.fm
❀  Pinterest
❀  FMHY
❀  X.com'
    local favorites_count
    favorites_count=$(printf '%s\n' "$favorites_entries" | wc -l)

    local config_entries='❀  aria2
❀  gallery-dl
❀  kitty
❀  waybar
❀  rofi
❀  hypr
❀  mpv
❀  swayimg
❀  yt-dlp
❀  swaync
❀  zathura
❀  fish'
    local config_count
    config_count=$(printf '%s\n' "$config_entries" | wc -l)

    local all_entries
    all_entries=$(printf '%s\n%s\n%s\n%s\n%s\n%s' "$favorites_entries" "$ai_entries" "$anime_entries" "$web_entries" "$streaming_entries" "$config_entries")
    local all_count
    all_count=$(printf '%s\n' "$all_entries" | wc -l)

    local chosen
    chosen=$(printf '❀  Search All (%s)\n❀  Favorites (%s)\n❀  Config (%s)\n❀  Web (%s)\n❀  AI (%s)\n❀  Anime (%s)\n❀  Streaming (%s)\n❀  Power' "$all_count" "$favorites_count" "$config_count" "$web_count" "$ai_count" "$anime_count" "$streaming_count" \
        | rofi_menu "❀  Sites:" 8)
    [[ -z "$chosen" ]] && exit 0

    case "$chosen" in
        *"Search All ("*")")
            local all_choice
            all_choice=$(printf '%s\n' "$all_entries" | rofi_menu "❀  All:")
            [[ -z "$all_choice" ]] && exit 0
            open_site_choice "$all_choice"
            ;;
        *"Favorites ("*")")
            local fav_choice
            fav_choice=$(printf '❀  Open All\n%s' "$favorites_entries" | rofi_menu "❀  Favorites:")
            [[ -z "$fav_choice" ]] && exit 0
            if [[ "$fav_choice" == *"Open All" ]]; then
                open_all "${favorites_urls[@]}"
            else
                open_site_choice "$fav_choice"
            fi
            ;;
        *"Config ("*")")
            local config_choice
            config_choice=$(printf '󰁯  Backup → dotfiles.zip\n❀  Open All\n%s' "$config_entries" | rofi_menu "❀  Config:" 14)
            [[ -z "$config_choice" ]] && exit 0
            if [[ "$config_choice" == *Backup* ]]; then
                cd "$HOME/.config" && zip -rq /home/w/dotfiles.zip aria2 gallery-dl kitty waybar rofi hypr mpv swayimg yt-dlp swaync zathura fish \
                    && hyprctl notify 5 3000 "rgb(a6e3a1)" "󰁯  Backup saved → ~/dotfiles.zip" \
                    || hyprctl notify 3 3000 "rgb(f38ba8)" "󰅗  Backup failed"
                exit 0
            fi
            if [[ "$config_choice" == *"Open All" ]]; then
                zeditor \
                    "$HOME/.config/aria2" \
                    "$HOME/.config/gallery-dl" \
                    "$HOME/.config/kitty" \
                    "$HOME/.config/waybar" \
                    "$HOME/.config/rofi" \
                    "$HOME/.config/hypr" \
                    "$HOME/.config/mpv" \
                    "$HOME/.config/swayimg" \
                    "$HOME/.config/yt-dlp" \
                    "$HOME/.config/swaync" \
                    "$HOME/.config/zathura" \
                    "$HOME/.config/fish" \
                    &>/dev/null &
                exit 0
            fi
            local cfg
            cfg=$(echo "$config_choice" | sed 's/^❀  //')
            zeditor "$HOME/.config/$cfg"
            ;;
        *"Web ("*")")
            local web_choice
            web_choice=$(printf '❀  Open All\n%s' "$web_entries" | rofi_menu "❀  Web:")
            [[ -z "$web_choice" ]] && exit 0
            if [[ "$web_choice" == *"Open All" ]]; then
                open_all "${web_urls[@]}"
            else
                open_site_choice "$web_choice"
            fi
            ;;
        *"AI ("*")")
            local ai_choice
            ai_choice=$(printf '❀  Open All\n%s' "$ai_entries" | rofi_menu "❀  AI:")
            [[ -z "$ai_choice" ]] && exit 0
            if [[ "$ai_choice" == *"Open All" ]]; then
                open_all "${ai_urls[@]}"
            else
                open_site_choice "$ai_choice"
            fi
            ;;
        *"Anime ("*")")
            local anime_choice
            anime_choice=$(printf '❀  Open All\n%s' "$anime_entries" | rofi_menu "❀  Anime:")
            [[ -z "$anime_choice" ]] && exit 0
            if [[ "$anime_choice" == *"Open All" ]]; then
                open_all "${anime_urls[@]}"
            else
                open_site_choice "$anime_choice"
            fi
            ;;
        *"Streaming ("*")")
            local streaming_choice
            streaming_choice=$(printf '❀  Open All\n%s' "$streaming_entries" | rofi_menu "❀  Streaming:")
            [[ -z "$streaming_choice" ]] && exit 0
            if [[ "$streaming_choice" == *"Open All" ]]; then
                open_all "${streaming_urls[@]}"
            else
                open_site_choice "$streaming_choice"
            fi
            ;;
        *"Power"*)
            local power_choice
            power_choice=$(printf '❀  Shutdown\n❀  Reboot\n❀  Logout' | rofi_menu "❀  Power:" 3)
            [[ -z "$power_choice" ]] && exit 0
            case "$power_choice" in
                *Shutdown) systemctl poweroff ;;
                *Reboot) systemctl reboot ;;
                *Logout) hyprctl dispatch exit 2>/dev/null || loginctl terminate-user "$USER" ;;
            esac
            ;;
    esac
}

run_sites_menu
