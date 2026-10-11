# tmux-projects

A project is a tmux session named `<area>/<project>`, and the area is the work/personal split.

## The problem

With AI I have a lot of windows open in tmux: different agents, each on its own piece of work, across several projects at once. A project is usually a repo, though not always. tmux windows alone make it difficult to tell which project each belongs to. I wanted them organised around projects, with a split between work and personal, the area, and a way to move between them.

## How it works

Four things have names. An area is the work/personal split, one folder of repos each, such as `~/Projects/personal`. A project is one thing you are working on, usually a repo, and is a tmux session named `<area>/<project>`, for example `personal/dotto`. A window is one piece of work inside a project, an agent or a shell. Every area also has Misc, the project for windows that belong to no repo yet.

The status bar shows two of these. The project row lists the projects of your area, numbered. The window row lists the windows of the project you are in.

Everything you do with them starts with `C-a p`:

1. Go: a number for a project, `p` for the last one, `a` for the other area, and `hjkl` to walk the rows.
2. Create: `c` makes a project from a repo.
3. Move: `m` takes this window to another project.
4. Rename: `,`.

Create and move each have a lowercase key that picks from a popup, with the cursor on the repo this pane is in, and an uppercase key that types the name. A name the area does not have yet gets made either way.

A project is a separate session rather than something new, because that is what other tools expect. Most of them assume they are working within a session, so Claude's teams, for one, work natively.

## Project Navigation & shortcuts

`C-a p` opens the project table, and the next key comes from it.

| Key | What it does |
| --- | --- |
| `1` to `9` | switch to that project |
| `p` or `Tab` | go back to the last project |
| `a` | flip to the other area |
| `,` | rename the project |
| `c` | pick a repo from the area's directory and create its project, with a window open there; one that already has a project just switches |
| `C` | create a project from a name you type |
| `m` | pick where this window goes: the area's projects, Misc included, then the repos with no project yet, which get one |
| `M` | move this window to a project whose name you type |

`C-a h`, `j`, `k` and `l` walk the bar itself. `h` and `l` step along a row, `j` drops to the window row and `k` rises to the project row. `Escape` puts you back where you started, and `Enter`, or any other key, keeps you where you landed.

## Install

Add the plugin line to `tmux.conf`, then `C-a I` installs it:

```tmux
set -g @plugin 'darrenbuse/tmux-projects'
```

The two options go above the TPM run line, so they are set when the plugin runs:

```tmux
set -g @tmux-projects-areas "personal=~/Projects/personal work=~/Projects/MnS"
set -g @tmux-projects-misc "Misc"
```

fzf is needed for the two popups, `C-a p c` and `C-a p m`, and git to find the repo a pane is in, which is where their cursor starts. The typed forms, `C-a p C` and `C-a p M`, need neither.

## Options

`@tmux-projects-areas` holds area=directory pairs separated by spaces, for example `personal=~/Projects/personal work=~/Projects/MnS`. The first area is where a fresh server opens, and an area not listed falls back to home.

`@tmux-projects-misc` holds the name of the pinned slot 1 project every area keeps. The default is `Misc`. When no session stands behind it, the slot 1 project is drawn dim.

## Licence

MIT.
