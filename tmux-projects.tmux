#!/usr/bin/env bash
# tmux-projects: a two-row status bar where a session is a project named
# <area>/<project>. Row 1 lists the projects of your area, row 2 the windows of the
# one you are in. TPM runs this file; it binds the keys to proj.sh beside it and
# sets the formats. The area map and the pinned slot name come from two options,
# set before TPM loads:
#
#   set -g @tmux-projects-areas "personal=~/Projects/personal work=~/Projects/MnS"
#   set -g @tmux-projects-misc  "Misc"
#
# The first area listed is the one a fresh server opens on.

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# The block turns yellow and gains a leading > the moment C-a is pressed, since
# C-a h/j/l start on the window row, and again while C-a p h/j/k/l has the window
# row; red with a space otherwise - one character either way, so the row does not
# shift as the cursor moves between the rows. The conditional holds only the colour
# name: a comma inside an arm splits the arms. See the nav bindings below.
tmux set -g window-status-current-format "#[fg=colour0]#[bg=#{?#{||:#{==:#{client_key_table},prefix},#{&&:#{==:#{client_key_table},nav},#{==:#{@nav_row},window}}},colour3,colour1}]#{?#{||:#{==:#{client_key_table},prefix},#{&&:#{==:#{client_key_table},nav},#{==:#{@nav_row},window}}},>, }#I:#{=/40/…:window_name}#F"

# --- Projects -------------------------------------------------------------
# A project is a session named <area>/<project>, eg personal/dotto. The area is
# everything before the first slash, so personal and work keep separate project
# lists in one server. Row 1 lists the projects in your area, row 2 the windows
# of the one you are in - so window numbers start at 1 again in every project,
# with no arithmetic, because each project is simply its own session.
tmux set -g status 2

# Closing the last shell in a project destroys the session, and by default that
# detaches the client and drops you out of tmux entirely. Fall back to the most
# recently active project instead, the same one C-a p p goes to.
tmux set -g detach-on-destroy off

# Row 2: the stock window bar, verbatim from tmux own status-format[0] default,
# moved down a line to make room for the projects above it.
tmux set -g 'status-format[1]' "#[list=on align=#{status-justify}]#[list=left-marker]<#[list=right-marker]>#[list=on]#{W:#[range=window|#{window_index} #{E:window-status-style}#{?#{&&:#{window_last_flag},#{!=:#{E:window-status-last-style},default}}, #{E:window-status-last-style},}#{?#{&&:#{window_bell_flag},#{!=:#{E:window-status-bell-style},default}}, #{E:window-status-bell-style},#{?#{&&:#{||:#{window_activity_flag},#{window_silence_flag}},#{!=:#{E:window-status-activity-style},default}}, #{E:window-status-activity-style},}}]#[push-default]#{T:window-status-format}#[pop-default]#[norange default]#{?loop_last_flag,,#{window-status-separator}},#[range=window|#{window_index} list=focus #{?#{!=:#{E:window-status-current-style},default},#{E:window-status-current-style},#{E:window-status-style}}#{?#{&&:#{window_last_flag},#{!=:#{E:window-status-last-style},default}}, #{E:window-status-last-style},}#{?#{&&:#{window_bell_flag},#{!=:#{E:window-status-bell-style},default}}, #{E:window-status-bell-style},#{?#{&&:#{||:#{window_activity_flag},#{window_silence_flag}},#{!=:#{E:window-status-activity-style},default}}, #{E:window-status-activity-style},}}]#[push-default]#{T:window-status-current-format}#[pop-default]#[norange list=on default]#{?loop_last_flag,,#{window-status-separator}}}#[nolist align=right range=right #{E:status-right-style}]#[push-default]#{T;=/#{status-right-length}:status-right}#[pop-default]#[norange default]"

# Row 1 is built by proj.sh rather than written as a format: tmux formats have
# no per-slot counter, only loop_last_flag, so the numbers you press cannot be
# rendered by a format alone. proj.sh writes the rendered row into the session's
# @projbar; reading it here keeps the status-format array global-only, because a
# session-level array would hide every global index and blank the window row.
tmux set -g 'status-format[0]' "#{E:@projbar}"

# Rebuilt only when the set of projects changes, never when you move between them
# or switch a window. Every session's row is built with itself already marked as
# the one you are in, so arriving at a session finds its row correct and needs no
# rebuild - which is what makes C-a p h/l cheap to hold down, at 105ms a rebuild
# across eleven sessions.
tmux set-hook -g session-created "run-shell -b \"$CURRENT_DIR/proj.sh bar\""
tmux set-hook -g session-closed "run-shell -b \"$CURRENT_DIR/proj.sh bar\""
tmux set-hook -g session-renamed "run-shell -b \"$CURRENT_DIR/proj.sh bar\""
tmux run-shell -b "$CURRENT_DIR/proj.sh bar"

# C-a p opens the project table and the next key is read from it - tmux own
# mechanism for a second prefix, see switch-client -T in tmux(1).
tmux bind p switch-client -T project
tmux bind -T project 1 run-shell "$CURRENT_DIR/proj.sh goto 1"
tmux bind -T project 2 run-shell "$CURRENT_DIR/proj.sh goto 2"
tmux bind -T project 3 run-shell "$CURRENT_DIR/proj.sh goto 3"
tmux bind -T project 4 run-shell "$CURRENT_DIR/proj.sh goto 4"
tmux bind -T project 5 run-shell "$CURRENT_DIR/proj.sh goto 5"
tmux bind -T project 6 run-shell "$CURRENT_DIR/proj.sh goto 6"
tmux bind -T project 7 run-shell "$CURRENT_DIR/proj.sh goto 7"
tmux bind -T project 8 run-shell "$CURRENT_DIR/proj.sh goto 8"
tmux bind -T project 9 run-shell "$CURRENT_DIR/proj.sh goto 9"
# Double-tapping p goes back to the project you came from, and again returns.
tmux bind -T project p switch-client -l
tmux bind -T project Tab switch-client -l
# a flips to the other area, personal or work: the numbers never leave the one you
# are in, so this is the way across. It lands on the project you were last in there,
# or makes that area's Misc when nothing stands - so a work area you closed at the end
# of the day is one key away the next morning.
tmux bind -T project a run-shell "$CURRENT_DIR/proj.sh area"
tmux bind -T project c run-shell "$CURRENT_DIR/proj.sh here"
# n starts a project from nothing, its shell in ~/Projects/personal or
# ~/Projects/MnS depending on the area you press it from.
tmux bind -T project n run-shell -b "$CURRENT_DIR/proj.sh new-prompt"
# N picks instead of typing: an fzf popup listing the area's directories that have
# no project yet, so the fifty-odd under work stay one filter away. Worktrees are
# folded into their repo, the way C-a p c already folds them.
tmux bind -T project N run-shell -b "$CURRENT_DIR/proj.sh pick"
# , renames this project, the key C-a , renames a window with, one level up.
# m spins the current window out into another project. Both prompt, prefilled with
# the window name, so the name stays yours to edit. -b matters: run-shell blocks the
# command queue, and these scripts open a prompt of their own, which cannot be
# processed while the queue is held.
tmux bind -T project , run-shell -b "$CURRENT_DIR/proj.sh rename-prompt"
tmux bind -T project m run-shell -b "$CURRENT_DIR/proj.sh move-prompt"
# M picks the destination instead of typing it: an fzf popup of the area's projects,
# Misc among them whether or not a session stands behind it yet. m still makes a
# project that is not there yet; M only offers the ones that are.
tmux bind -T project M run-shell -b "$CURRENT_DIR/proj.sh move-pick"

# h/j/k/l drive the bar itself. h and l step along a row, j drops to the window row
# and k rises to the project row, and a step really switches rather than moving a
# highlight, so row 2 shows the windows of the project under the cursor. These enter
# the nav table, which binds them again so the mode stays open until you leave it.
#
# Two ways in, one mode, and the only difference is the row the cursor starts on.
# C-a l walks the windows of this project, C-a p l walks the projects - each key
# starting on the row you reached for it to move you along. From either, j and k
# change rows, so neither way in shuts the other row out. C-a l was last-window;
# panes are on M-hjkl, so the prefix keys were otherwise free.
tmux bind h run-shell -b "$CURRENT_DIR/proj.sh nav enter window left"
tmux bind l run-shell -b "$CURRENT_DIR/proj.sh nav enter window right"
tmux bind j run-shell -b "$CURRENT_DIR/proj.sh nav enter window"
tmux bind k run-shell -b "$CURRENT_DIR/proj.sh nav enter project"
tmux bind -T project h run-shell -b "$CURRENT_DIR/proj.sh nav enter project left"
tmux bind -T project l run-shell -b "$CURRENT_DIR/proj.sh nav enter project right"
tmux bind -T project j run-shell -b "$CURRENT_DIR/proj.sh nav enter window"
tmux bind -T project k run-shell -b "$CURRENT_DIR/proj.sh nav enter project"
tmux bind -T nav h run-shell -b "$CURRENT_DIR/proj.sh nav left"
tmux bind -T nav l run-shell -b "$CURRENT_DIR/proj.sh nav right"
tmux bind -T nav j run-shell -b "$CURRENT_DIR/proj.sh nav down"
tmux bind -T nav k run-shell -b "$CURRENT_DIR/proj.sh nav up"
# Nothing below re-arms the table, so each of these ends the mode. Escape puts back
# the session and window you started from; Enter keeps where you have landed; any
# other key keeps it too and is sent on to the pane, so the key you meant to type
# is not eaten by the mode - send-keys with no arguments resends the key that got
# here, see send-keys in tmux(1). The separator is quoted because from bash a bare
# \; reaches tmux as ; and splits the line into two commands, leaving the binding
# with only the first.
tmux bind -T nav Escape run-shell -b "$CURRENT_DIR/proj.sh nav cancel"
tmux bind -T nav Enter run-shell -b "$CURRENT_DIR/proj.sh nav commit"
tmux bind -T nav Any run-shell -b "$CURRENT_DIR/proj.sh nav commit" '\;' send-keys
# The prefix is the one key that must not be sent on: C-a in a shell is start of
# line, and you pressed it to begin a command. It ends the mode as a prefix instead.
tmux bind -T nav C-a run-shell -b "$CURRENT_DIR/proj.sh nav commit" '\;' switch-client -T prefix
