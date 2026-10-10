# tmux-projects

A project is a tmux session named `<area>/<project>`, and the area is the work/personal split.

## The problem

With AI in the mix I have a lot of windows open in tmux: different agents, each on its own piece of work, across several projects at once. A project is usually a repo, though not always. Windows on their own do not say which project each belongs to, so I wanted them organised around projects, with a split between work and personal, and a way to move between them.

## How it works

Sessions give most of what I want. What they lack is granularity, so a project here is a wrapper around a session. The session is named `<area>/<project>`, and the area, the part before the slash, is the work/personal split.

Row 1 of the status bar lists the projects of your area, numbered. Row 2 lists the windows of the one you are in.

A project stays a separate session rather than something new, because that is what other tools expect. Most of them assume they are working within a session, so Claude's teams, for one, work natively.

## Project Navigation & shortcuts

`C-a p` opens the project table, and the next key comes from it.

| Key | What it does |
| --- | --- |
| `1` to `9` | switch to that project |
| `p` or `Tab` | go back to the last project |
| `a` | flip to the other area |
| `c` | switch to, or create, the project for the repo this pane is in |
| `n` | make a project from nothing |
| `N` | pick one of the area's directories from an fzf popup |
| `,` | rename the project |
| `m` | move this window to another project, typed |
| `M` | pick the destination project from a popup |

`C-a h`, `j`, `k` and `l` walk the bar itself. `h` and `l` step along a row, `j` drops to the window row and `k` rises to the project row. `Escape` puts back where you started, and `Enter`, or any other key, keeps where you landed.

## Install

Add the plugin line to `tmux.conf`, then `prefix + I` installs it:

```tmux
set -g @plugin 'darrenbuse/tmux-projects'
```

The two options go above the TPM run line, so they are set when the plugin runs:

```tmux
set -g @tmux-projects-areas "personal=~/Projects/personal work=~/Projects/MnS"
set -g @tmux-projects-misc "Misc"
```

fzf is needed for the two popups, `C-a p N` and `C-a p M`, and git for `C-a p c`, which finds the repo a pane is in.

## Options

`@tmux-projects-areas` holds area=directory pairs separated by spaces, for example `personal=~/Projects/personal work=~/Projects/MnS`. The first area is where a fresh server opens, and an area not listed falls back to home.

`@tmux-projects-misc` holds the name of the pinned slot 1 project every area keeps. The default is `Misc`, and it is drawn dim when no session stands behind it.

## Licence

MIT.
