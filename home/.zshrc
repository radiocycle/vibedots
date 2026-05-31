export PATH="$HOME/.local/bin:$PATH"

export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME=""

# History
HISTSIZE=10000
SAVEHIST=10000
HISTFILE=~/.zsh_history

# Plugins
plugins=(
    git
    sudo
    dirhistory
    copypath
    copyfile
    web-search
    battery
    extract
    colored-man-pages
)

source $ZSH/oh-my-zsh.sh

# ── Системные плагины из репозитория ────────────────────────
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh

# Дополнительные completions
fpath=(/usr/share/zsh/site-functions $fpath)

# ── История: поиск стрелками ─────────────────────────────────
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down
bindkey "$terminfo[kcuu1]" history-substring-search-up
bindkey "$terminfo[kcud1]" history-substring-search-down

# ── Completion ───────────────────────────────────────────────
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

# ── Autosuggestions ──────────────────────────────────────────
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#6c7086'
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
bindkey '^ ' autosuggest-accept   # Ctrl+Space принять подсказку

# ── Алиасы ───────────────────────────────────────────────────
alias ls='ls --color=auto'
alias ll='ls -lah --color=auto'
alias la='ls -A --color=auto'
alias grep='grep --color=auto'
alias ..='cd ..'
alias ...='cd ../..'
alias ff='fastfetch'
alias pac='sudo pacman'

eval "$(starship init zsh)"
