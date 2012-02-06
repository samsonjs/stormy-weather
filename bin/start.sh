#!/bin/zsh

[[ -d "$HOME/.rbenv" ]] && export PATH="$HOME/.rbenv/shims:$PATH"

if [[ "$RACK_ENV" = "development" ]]; then
    exec shotgun -s thin -o 0.0.0.0 -p 5000 config.ru
else
    [[ -d /web/stormy ]] && cd /web/stormy
    [[ -d log ]] || mkdir log
    RACK_ENV=production bin/start.rb >>|log/access.log 2>>|log/access.log &!
    if [[ $? -eq 0 ]]; then
        echo $! >|./pid
    else
        echo "!! Failed to start. Last bit of the log:"
        tail -n 20 log/access.log
    fi
fi
