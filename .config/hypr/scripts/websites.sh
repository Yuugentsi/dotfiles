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
            -theme-str '* { font: "JetBrainsMono Nerd Font Medium 10.5"; bg: rgba(12,4,8,0.75); bg-alt: rgba(255,255,255,0.05); bg-hover: rgba(200,90,120,0.25); fg: #ffe0ec; muted: #b898a8; accent: #f8b4c8; glow: rgba(248,180,200,0.5); }' \
            -theme-str 'window { width: 54%; background-color: @bg; transparency: "real"; border: 2px; border-color: @glow; border-radius: 18px; }' \
            -theme-str 'mainbox { background-color: transparent; padding: 8px; spacing: 4px; }' \
            -theme-str 'inputbar { background-color: rgba(255,255,255,0.07); padding: 6px 10px; border: 1px; border-color: rgba(248,180,200,0.2); border-radius: 10px; children: [ entry ]; }' \
            -theme-str 'entry { background-color: transparent; text-color: @fg; placeholder-color: @muted; cursor-color: @accent; cursor-width: 2px; }' \
            -theme-str "listview { columns: 1; lines: ${lines}; fixed-height: false; dynamic: true; spacing: 2px; scrollbar: true; scrollbar-width: 4px; }" \
            -theme-str 'scrollbar { background-color: transparent; handle-color: @accent; handle-width: 4px; border-radius: 2px; }' \
            -theme-str 'element { background-color: @bg-alt; text-color: @fg; padding: 4px 8px; height: 28px; border: 1px; border-color: rgba(255,255,255,0.03); border-radius: 8px; }' \
            -theme-str 'element normal.normal { background-color: @bg-alt; text-color: @fg; }' \
            -theme-str 'element alternate.normal { background-color: @bg-alt; text-color: @fg; }' \
            -theme-str 'element selected.normal { background-color: @bg-hover; text-color: @accent; border: 2px; border-color: @accent; }' \
            -theme-str 'element-text { background-color: transparent; text-color: @fg; vertical-align: 0.5; highlight: bold #ffffff; }' \
            -theme-str 'element normal.normal element-text { background-color: transparent; text-color: @fg; }' \
            -theme-str 'element alternate.normal element-text { background-color: transparent; text-color: @fg; }' \
            -theme-str 'element selected.normal element-text { background-color: transparent; text-color: @accent; }' \
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
        "https://www.miruro.tv/"
        "https://kuudere.ru"
        "https://kaa.lt/"
    )

    local web_urls=(
        "https://reddit.com"
        "https://letterboxd.com/yuugentsi/"
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
        "https://citywalks.live"
        "https://www.lofi.cafe/"
    )

    local streaming_urls=(
        "https://www.cineby.sc/"
        "https://67movies.net"
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

    local tech_urls=(
        "https://hackernoon.com/"
        "https://www.reuters.com/technology/"
        "https://www.wsj.com/tech"
        "https://www.androidpolice.com/"
        "https://techcrunch.com/"
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
            *Miruro) "$BROWSER" "https://www.miruro.tv/" ;;
            *Kuudere) "$BROWSER" "https://kuudere.ru" ;;
            *Kaa) "$BROWSER" "https://kaa.lt/" ;;
            *Twitter) "$BROWSER" "https://x.com" ;;
            *Reddit) "$BROWSER" "https://reddit.com" ;;
            *Letterboxd) "$BROWSER" "https://letterboxd.com/yuugentsi/" ;;
            *Pinterest) "$BROWSER" "https://pinterest.com" ;;
            *Last.fm) "$BROWSER" "https://last.fm/user/yuugentsi" ;;
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
            *GitHub) "$BROWSER" "https://github.com/yuugentsi" ;;
            *Wikipedia) "$BROWSER" "https://wikipedia.org" ;;
            *Proton\ Mail) "$BROWSER" "https://mail.proton.me/u/0/inbox" ;;
            *Proton\ Pass) "$BROWSER" "https://pass.proton.me/u/0" ;;
            *CityWalks) "$BROWSER" "https://citywalks.live" ;;
            *Lofi\ Cafe) "$BROWSER" "https://www.lofi.cafe/" ;;
            *X.com) "$BROWSER" "https://x.com" ;;
            *HackerNoon) "$BROWSER" "https://hackernoon.com/" ;;
            *Reuters\ Tech) "$BROWSER" "https://www.reuters.com/technology/" ;;
            *WSJ\ Tech) "$BROWSER" "https://www.wsj.com/tech" ;;
            *Android\ Police) "$BROWSER" "https://www.androidpolice.com/" ;;
            *TechCrunch) "$BROWSER" "https://techcrunch.com/" ;;
            *Cineby) "$BROWSER" "https://www.cineby.sc/" ;;
            *67Movies) "$BROWSER" "https://67movies.net" ;;
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
❀  Proton Pass
❀  CityWalks
❀  Lofi Cafe'
    local web_count
    web_count=$(printf '%s\n' "$web_entries" | wc -l)

    local streaming_entries='❀  Cineby
❀  67Movies
❀  PopcornMovies
❀  ShuttleTV'
    local streaming_count
    streaming_count=$(printf '%s\n' "$streaming_entries" | wc -l)

    local tech_entries='❀  HackerNoon
❀  Reuters Tech
❀  WSJ Tech
❀  Android Police
❀  TechCrunch'
    local tech_count
    tech_count=$(printf '%s\n' "$tech_entries" | wc -l)

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
    all_entries=$(printf '%s\n%s\n%s\n%s\n%s\n%s\n%s' "$favorites_entries" "$ai_entries" "$anime_entries" "$tech_entries" "$web_entries" "$streaming_entries" "$config_entries")
    local all_count
    all_count=$(printf '%s\n' "$all_entries" | wc -l)

    handle_bang() {
        local input="$1"
        local bang query encoded
        bang=${input%% *}
        query=${input#* }
        [ "$bang" = "$query" ] && query=""
        encoded=$(python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1]))" "$query" 2>/dev/null || printf '%s' "$query")

        case "$bang" in
            # search
            .youtube|.yt) "$BROWSER" "https://www.youtube.com/results?search_query=$encoded" ;;
            .x|.twitter)   "$BROWSER" "https://x.com/search?q=$encoded&src=typed_query" ;;
            .dan|.danbooru) "$BROWSER" "https://danbooru.donmai.us/posts?tags=$encoded&z=5" ;;
            .lastfm|.last) "$BROWSER" "http://last.fm/user/$encoded" ;;

            # direct
            .walltop|.wall) "$BROWSER" "https://wallhaven.cc/toplist" ;;
            .wallhot)       "$BROWSER" "https://wallhaven.cc/hot" ;;
            .github)
                if [ -n "$query" ]; then
                    "$BROWSER" "https://github.com/$encoded"
                else
                    "$BROWSER" "https://github.com/yuugentsi"
                fi
                ;;
            .git) "$BROWSER" "https://github.com/$encoded" ;;

            # system
            .update) kitty -e sudo pacman -Syyu ;;
            .ins)    kitty -e sudo pacman -S --noconfirm "$query" ;;
            .reboot) systemctl reboot ;;
            .power)  systemctl poweroff ;;

            # search
            .g) "$BROWSER" "https://www.google.com/search?q=$encoded" ;;
        esac
    }

    local chosen
    chosen=$(printf '❀  Search All (%s)\n❀  Favorites (%s)\n❀  Config (%s)\n❀  Web (%s)\n❀  Tech (%s)\n❀  AI (%s)\n❀  Anime (%s)\n❀  Streaming (%s)\n❀  Power' "$all_count" "$favorites_count" "$config_count" "$web_count" "$tech_count" "$ai_count" "$anime_count" "$streaming_count" \
        | rofi_menu "❀  Sites:" 8)
    [[ -z "$chosen" ]] && exit 0

    case "$chosen" in
        '.'*)
            handle_bang "$chosen"
            exit 0
            ;;
        https://www.youtube.com/*|https://youtube.com/*|https://youtu.be/*)
            kitty --hold -e bash -c "mkdir -p '$HOME/0/music/yt' && yt-dlp -x --audio-format mp3 --audio-quality 0 -P '$HOME/0/music/yt' -o '%(title)s.%(ext)s' '$chosen' && read -p 'Done. Press enter...'"
            exit 0
            ;;
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
            if [[ "$config_choice" == *"Emoji Picker" ]]; then
            rofi -modi emoji -show emoji -emoji-format '{emoji}' -emoji-mode copy
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
        *"Tech ("*")")
            local tech_choice
            tech_choice=$(printf '❀  Open All\n%s' "$tech_entries" | rofi_menu "❀  Tech:")
            [[ -z "$tech_choice" ]] && exit 0
            if [[ "$tech_choice" == *"Open All" ]]; then
                open_all "${tech_urls[@]}"
            else
                open_site_choice "$tech_choice"
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
