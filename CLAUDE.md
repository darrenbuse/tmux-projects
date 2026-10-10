# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What is here

A tmux plugin. `tmux-projects.tmux` is the entry file TPM runs: it sets the two status rows and binds the keys to `proj.sh` beside it. `proj.sh` does the switching; its header comment lists the subcommands. `README.md` is drafted from `README-notes.md`, which stays local.

## Setup

```bash
npm install  # Required to enable git hooks (husky)
```

## Trying a change

Reload the config in a running server and the entry file runs again from this folder when it is the installed copy at `~/.tmux/plugins/tmux-projects`:

```bash
tmux source-file ~/.tmux.conf
```
