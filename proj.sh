#!/bin/bash

# Project switching for the two-row status bar. A project is a session named
# <area>/<project>, eg personal/dotto, so personal and work keep separate project
# lists in one server and everything below is scoped to the area you are in.
#
#   start      a fresh server: make every area's Misc and attach the first
#   area       flip to the other area, its last project or a Misc made on arrival
#   bar        rebuild row 1, the project list, for every session
#   goto <n>   switch to the nth project of the current area, numbered by name
#   new        create a project, its shell starting in the area's directory
#   pick       choose a repo in the area's directory and make its project, the
#              cursor on this pane's repo, or type a name the list does not have
#   move-pick  choose where this window goes: the area's projects, then the repos
#              with no project yet, the cursor on this pane's repo
#   nav        drive the two status rows with hjkl, Escape putting back the start
#              enter <row> [step] - which row the cursor starts on, and one step
#   rename     rename this project, prompting from the window or directory
#   move       move this window into another project, creating it if new
#
# Every area keeps a Misc project at slot 1. It is drawn whether or not a session
# exists behind it - dim when there is none - because a tmux session cannot have
# zero windows, so an empty Misc is no session at all. C-a p 1 creates it rooted at
# the area's projects directory. That way slot 1 never moves and never disappears.
#
# Row 1 is built here rather than written as a tmux format because formats have no
# per-slot counter - there is loop_last_flag and nothing else - so the numbers you
# press cannot be rendered by a format alone. Only session create, close, rename and
# switch rebuild it, never a window switch: run-shell blocks the tmux command queue
# while it runs, so it must stay off the hot path.
#
# Errors go to display-message. run-shell failures are invisible to command-error,
# and anything printed on stdout would open a view-mode pane over the current window.

SELF=$0

msg() {
	tmux display-message "$1"
}

# The session this was invoked from. $TMUX_PANE is set for keybindings and for
# anything run inside a pane; without it tmux picks the most recently used session,
# which is a coin toss when two clients are attached.
cur_session() {
	# A popup is not a pane, so $TMUX_PANE is empty inside one. The binding that
	# opens the popup knows the session for certain and passes it in.
	if [ -n "$TMUX_SESSION" ]; then
		printf '%s' "$TMUX_SESSION"
	elif [ -n "$TMUX_PANE" ]; then
		tmux display-message -p -t "$TMUX_PANE" '#{session_name}'
	else
		tmux display-message -p '#{session_name}'
	fi
}

# The client this was invoked from. A popup has none of its own, so the binding
# that opens one passes it in; everywhere else it is the client whose pane the key
# was pressed in, which beats letting tmux guess between two attached clients.
cur_client() {
	if [ -n "$TMUX_CLIENT" ]; then
		printf '%s' "$TMUX_CLIENT"
	else
		tmux display-message -p -t "${TMUX_PANE:-}" '#{client_name}'
	fi
}

# Every switch goes through here rather than half of them knowing which client to
# move.
switch_to() {
	client=$(cur_client)
	if [ -n "$client" ]; then
		tmux switch-client -c "$client" -t "=$1"
	else
		tmux switch-client -t "=$1"
	fi
}

# The window this was invoked from. Same reason as cur_session: a popup has no
# $TMUX_PANE, so the binding that opens it passes the window in.
cur_window() {
	if [ -n "$TMUX_WINDOW" ]; then
		printf '%s' "$TMUX_WINDOW"
	else
		tmux display-message -p -t "${TMUX_PANE:-}" '#{window_id}'
	fi
}

pane_path() {
	tmux display-message -p -t "${TMUX_PANE:-}" '#{pane_current_path}'
}

# The pinned slot 1 name and the area map come from tmux.conf, see the header of
# tmux-projects.tmux. Read once per run: every command is a fresh process. stderr
# is dropped because start runs this with no server yet, and reads them itself.
MISC=$(tmux show -gqv @tmux-projects-misc 2>/dev/null)
MISC=${MISC:-Misc}
AREAS=$(tmux show -gqv @tmux-projects-areas 2>/dev/null)

# The areas in the order they were listed, one per line. The first is where a
# fresh server opens, and C-a p a walks them in this order.
areas() {
	for pair in $AREAS; do
		printf '%s\n' "${pair%%=*}"
	done
}

# Where a Misc project starts, and where a new project starts when it has no
# directory of its own yet. A leading ~ is expanded here because tmux does not
# expand it inside a quoted option. An area not listed falls back to home rather
# than failing to create the session.
area_dir() {
	for pair in $AREAS; do
		case $pair in
		"$1="*)
			dir=${pair#*=}
			printf '%s' "${dir/#\~/$HOME}"
			return 0
			;;
		esac
	done
	printf '%s' "$HOME"
}

# Project sessions of one area, name order. That order is what the numbers follow,
# from 2 - Misc holds slot 1 and is left out here.
sessions_in() {
	tmux list-sessions -F '#{session_name}' 2>/dev/null |
		grep "^$1/" | grep -v "^$1/$MISC\$" | sort
}

# Make the area's Misc if it is not there. Every way in goes through here, so a
# Misc made by moving a window into it is rooted the same as one made by C-a p 1.
ensure_misc() {
	target="$1/$MISC"
	tmux has-session -t "=$target" 2>/dev/null && return 0
	dir=$(area_dir "$1")
	tmux new-session -d -s "$target" -c "$dir"
	# Read by bind c in tmux.conf: a new window in Misc starts in the area's
	# projects directory rather than following wherever the pane has cd'd to.
	tmux set -t "=$target:" @misc_dir "$dir"
}

# Switch to the area's Misc, making it first if it is not there.
goto_misc() {
	ensure_misc "$1"
	switch_to "$1/$MISC"
}

# A fresh server, from zshrc. Every area gets its Misc, so C-a p a has somewhere to
# land from the first moment, and the screen opens on the first area listed.
start() {
	# zshrc runs this before any server exists, so the two options read at the top
	# came back empty. start-server loads tmux.conf, which sets them, and the shows
	# in the same command read them before the empty server exits again.
	opts=$(tmux start-server \; show -gqv @tmux-projects-areas \; show -gqv @tmux-projects-misc)
	AREAS=$(printf '%s\n' "$opts" | sed -n 1p)
	MISC=$(printf '%s\n' "$opts" | sed -n 2p)
	MISC=${MISC:-Misc}
	for area in $(areas); do
		ensure_misc "$area"
	done
	tmux attach -t "=$(areas | head -1)/$MISC"
}

# C-a p a: the one deliberate jump across areas, since the numbers and h/l never
# leave the one you are in. It lands on the other area's most recently visited
# project, or when nothing stands there, on a Misc made on arrival - the same rule
# slot 1 follows, so a closed work area costs nothing to come back to.
area_flip() {
	self=$(cur_session)
	# The next area in the listed order, wrapping, so with two areas it is simply
	# the other one. An area not listed goes to the first.
	other=$(areas | grep -A1 -xF "${self%%/*}" | sed -n 2p)
	[ -n "$other" ] || other=$(areas | head -1)
	target=$(tmux list-sessions -F '#{session_last_attached} #{session_name}' 2>/dev/null |
		grep " $other/" | sort -rn | head -1 | cut -d' ' -f2-)
	if [ -z "$target" ]; then
		ensure_misc "$other"
		target="$other/$MISC"
	fi
	switch_to "$target"
}

# True while the project row has the keys: from C-a p, where C-a p h/l start, and
# while C-a p h/j/k/l is driving the rows with the cursor on this row. The window
# row lights from C-a alone, see window-status-current-format in tmux-projects.tmux.
nav_on_project() {
	printf '%s' "#{||:#{==:#{client_key_table},project},#{&&:#{==:#{client_key_table},$NAV_TABLE},#{==:#{@nav_row},project}}}"
}

# The cursor drawn on the current project while the project row has the keys, and
# a space otherwise. It goes into the row as a format, expanded on every redraw,
# so moving between the rows costs no rebuild. Both arms are one character wide,
# or the bar would jiggle as you press j.
nav_cursor() {
	printf '%s' "#{?$(nav_on_project),>, }"
}

# The style of the session's own slot: yellow while the project row has the keys,
# red otherwise, matching window-status-current-format on the window row. The
# conditional holds only the colour name, because a comma inside an arm splits it.
nav_style() {
	printf '%s' "#[fg=colour0,bold]#[bg=#{?$(nav_on_project),colour3,colour1}]"
}

bar() {
	# name and id together, one call rather than one per session
	ids=$(tmux list-sessions -F '#{session_name} #{session_id}' 2>/dev/null)
	[ -n "$ids" ] || return 0

	echo "$ids" | while read -r self _; do
		area=${self%%/*}
		# status-left rides on row 1 with the projects, not on the window row.
		# It stays a tmux option so tmux.conf keeps saying how it looks.
		out="#[align=left range=left #{E:status-left-style}]#[push-default]#{T;=/#{status-left-length}:status-left}#[pop-default]#[norange default]"
		# Slot 1 is always Misc, dim when no session stands behind it. With no session
		# there is no id to click, so the dim slot is not a range - C-a p 1 makes it.
		misc="$area/$MISC"
		miscid=$(echo "$ids" | awk -v m="$misc" '$1 == m { print $2; exit }')
		if [ "$self" = "$misc" ]; then
			miscstyle="$(nav_style)"
		elif [ -n "$miscid" ]; then
			miscstyle="#[fg=colour0,bg=colour2]"
		else
			miscstyle="#[fg=colour8,bg=colour2]"
		fi
		if [ "$self" = "$misc" ]; then
			misclabel="$(nav_cursor)1 $MISC "
		else
			misclabel=" 1 $MISC "
		fi
		if [ -n "$miscid" ]; then
			out="$out#[range=session|$miscid]$miscstyle$misclabel#[norange]#[default]"
		else
			out="$out$miscstyle$misclabel#[default]"
		fi

		n=1
		while read -r name id; do
			# A session with no slash predates the scheme, or was made by hand. It
			# becomes an area of one rather than dropping off the bar entirely.
			case $name in
			"$area"/* | "$area") ;;
			*) continue ;;
			esac
			[ "$name" = "$misc" ] && continue
			n=$((n + 1))
			label=${name#*/}
			if [ "$name" = "$self" ]; then
				style="$(nav_style)"
				slot="$(nav_cursor)$n $label "
			else
				style="#[fg=colour0,bg=colour2]"
				slot=" $n $label "
			fi
			out="$out#[range=session|$id]$style$slot#[norange]#[default]"
		done < <(echo "$ids" | sort)
		# set-option takes a target-pane, so the session needs a trailing colon;
		# "=" makes it exact, or a session named 1 would match 10. The row goes in
		# a user option, not session-level status-format[0]: a session-level array
		# hides every global index, so setting [0] there blanks the window row.
		tmux set -t "=$self:" @projbar "$out"
	done
}

goto() {
	self=$(cur_session)
	area=${self%%/*}
	if [ "$1" = 1 ]; then
		goto_misc "$area"
		return 0
	fi

	target=$(sessions_in "$area" | sed -n "$(($1 - 1))p")
	if [ -z "$target" ]; then
		msg "no project $1 in $area"
		return 0
	fi
	switch_to "$target"
}

# The project a directory belongs to. --git-common-dir, not --show-toplevel: toplevel
# differs per worktree, so one repo would become one project per worktree, and
# worktrees are how parallel agents run. Common-dir is shared, so they all land
# together. Inside a submodule, climb to the superproject.
repo_root() {
	dir=$1
	sup=$(cd "$dir" 2>/dev/null && git rev-parse --show-superproject-working-tree 2>/dev/null)
	[ -n "$sup" ] && dir=$sup
	common=$(cd "$dir" 2>/dev/null && git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
	[ -n "$common" ] || return 1
	dirname "$common"
}

repo_name() {
	root=$(repo_root "$1") || return 1
	basename "$root"
}

# Window names carry spaces and whatever else was typed; session names are targets,
# where a space is awkward and "." and ":" mean something. Case is kept, so a repo
# called Headsoup stays Headsoup.
slug() {
	name=$(printf '%s' "$1" | tr ' \t' '--' | tr -cd 'A-Za-z0-9_-' | sed 's/--*/-/g; s/^-//; s/-$//')
	# misc in any case means the pinned slot, not a project of its own. Without this,
	# typing it at the move prompt makes a second one and the row shows Misc and misc.
	case $name in
	[Mm][Ii][Ss][Cc]) name=$MISC ;;
	esac
	printf '%s' "$name"
}

win_name() {
	tmux display-message -p -t "${TMUX_PANE:-}" '#{window_name}'
}

# What a prompt prefills with. A window nobody has renamed is called after whatever
# is running in it - zsh - which says nothing about the work, so fall back to the
# repo the pane is sitting in, or failing that the directory it is sitting in.
suggest_name() {
	name=$(win_name)
	cmd=$(tmux display-message -p -t "${TMUX_PANE:-}" '#{pane_current_command}')
	if [ "$name" != "$cmd" ]; then
		slug "$name"
		return 0
	fi
	path=$(pane_path)
	slug "$(repo_name "$path" || basename "$path")"
}

# Both prompts prefill and let it be edited, so renaming to something the window is
# not called costs nothing extra.
rename_prompt() {
	self=$(cur_session)
	case $self in
	*/*) ;;
	*)
		msg "session '$self' has no area - rename it first, eg: tmux rename-session personal/misc"
		return 0
		;;
	esac
	tmux command-prompt -I "$(suggest_name)" -p "rename ${self%%/*}/" \
		"run-shell \"$SELF rename '%%'\""
}

move_prompt() {
	self=$(cur_session)
	case $self in
	*/*) ;;
	*)
		msg "session '$self' has no area - rename it first, eg: tmux rename-session personal/misc"
		return 0
		;;
	esac
	tmux command-prompt -I "$(suggest_name)" -p "move window to ${self%%/*}/" \
		"run-shell \"$SELF move '%%'\""
}

# A new project has no name yet, so this one prompts empty.
new_prompt() {
	self=$(cur_session)
	case $self in
	*/*) ;;
	*)
		msg "session '$self' has no area - rename it first, eg: tmux rename-session personal/misc"
		return 0
		;;
	esac
	tmux command-prompt -p "new ${self%%/*}/" "run-shell \"$SELF new '%%'\""
}

# The shell starts in the directory given, else in the project's own directory
# under the area when one exists there - the usual case, where the repo was cloned
# first - else in the area's directory.
new_project() {
	self=$(cur_session)
	area=${self%%/*}
	name=$(slug "$1")
	[ -n "$name" ] || return 0
	target="$area/$name"
	if tmux has-session -t "=$target" 2>/dev/null; then
		msg "$target already exists"
		switch_to "$target"
		return 0
	fi
	dir=$2
	if [ -z "$dir" ]; then
		dir=$(area_dir "$area")
		[ -d "$dir/$name" ] && dir="$dir/$name"
	fi
	tmux new-session -d -s "$target" -c "$dir"
	switch_to "$target"
}

# Repos in the area's directory, name order. A directory with no .git is left off.
# A worktree resolves to its parent repo: repo_root folds worktrees together, so a
# project named after one is somewhere the pane's repo could never be. A worktree's
# .git is a file whose gitdir: line names the parent, so telling them apart costs
# no git call.
repos() {
	dir=$(area_dir "$1")
	for path in "$dir"/*/; do
		[ -e "$path.git" ] || continue
		name=$(basename "$path")
		if [ -f "$path.git" ]; then
			gitdir=$(sed -n 's/^gitdir: //p' "$path.git")
			case $gitdir in
			*/.git/worktrees/*) name=$(basename "${gitdir%%/.git/worktrees/*}") ;;
			esac
		fi
		slug "$name"
		echo
	done | sort -u
}

# Repos with no project behind them yet.
candidates() {
	repos "$1" |
		grep -vxF -f <(tmux list-sessions -F '#{session_name}' 2>/dev/null | sed -n "s|^$1/||p")
}

# A list with the given name first, so the fzf cursor starts on it, and once only.
# Given nothing, the list as it came.
hoist() {
	if [ -n "$1" ]; then
		printf '%s\n' "$1"
		grep -vxF "$1"
	else
		cat
	fi
}

# Two stages. This one runs in a pane, where the session, the client and the pane's
# repo are known rather than guessed, and hands them to the popup, which has none.
pick() {
	self=$(cur_session)
	case $self in
	*/*) ;;
	*)
		msg "session '$self' has no area - rename it first, eg: tmux rename-session personal/misc"
		return 0
		;;
	esac
	tmux display-popup -E -w 50% -h 50% \
		-e "TMUX_SESSION=$self" \
		-e "TMUX_CLIENT=$(tmux display-message -p -t "${TMUX_PANE:-}" '#{client_name}')" \
		-e "TMUX_REPO=$(repo_root "$(pane_path)")" \
		"$SELF pick-fzf"
}

# Inside the popup. The list is rebuilt rather than passed through a file: it is one
# stat per directory, and a stale list would miss a repo cloned while it was open.
# The pane's repo goes first, whether or not it is under the area, so Enter makes
# its project rooted where the pane is. --print-query puts the typed text on line 1
# and the pick, if any, on line 2, and Enter on no match exits 1 rather than 0, so a
# name the list does not have becomes the project. Escape exits 130 and makes
# nothing.
pick_fzf() {
	area=$(cur_session)
	area=${area%%/*}
	pane=
	[ -n "$TMUX_REPO" ] && pane=$(slug "$(basename "$TMUX_REPO")")
	out=$(repos "$area" | hoist "$pane" | fzf --reverse --no-multi --print-query --prompt "project $area/")
	case $? in 0 | 1) ;; *) return 0 ;; esac
	name=$(sed -n '2p' <<<"$out")
	[ -n "$name" ] || name=$(sed -n '1p' <<<"$out")
	[ -n "$name" ] || return 0
	root=
	[ "$(slug "$name")" = "$pane" ] && root=$TMUX_REPO
	new_project "$name" "$root"
}

# Where this window could go among the projects that stand: the area's bar the one
# it is in, Misc first whether or not a session stands behind it yet - the same
# always-there rule the bar draws slot 1 by. move_pick_fzf adds the repos with no
# project yet after these.
move_targets() {
	area=${1%%/*}
	[ "$1" = "$area/$MISC" ] || echo "$MISC"
	sessions_in "$area" | sed "s|^$area/||" | grep -vxF "${1#*/}"
}

# Two stages, as pick is: this half runs in a pane and hands the popup the session,
# the client, the window and the pane's repo, none of which a popup can work out
# for itself.
move_pick() {
	self=$(cur_session)
	case $self in
	*/*) ;;
	*)
		msg "session '$self' has no area - rename it first, eg: tmux rename-session personal/misc"
		return 0
		;;
	esac
	tmux display-popup -E -w 50% -h 50% \
		-e "TMUX_SESSION=$self" \
		-e "TMUX_CLIENT=$(tmux display-message -p -t "${TMUX_PANE:-}" '#{client_name}')" \
		-e "TMUX_WINDOW=$(tmux display-message -p -t "${TMUX_PANE:-}" '#{window_id}')" \
		-e "TMUX_REPO=$(repo_root "$(pane_path)")" \
		"$SELF move-pick-fzf"
}

# Inside the popup. The list is rebuilt here rather than passed in, as pick does it,
# so a project made while the popup was open is on it. The pane's repo goes first,
# unless it is the project the window is already in, and the typed text is read the
# way pick_fzf reads it, so a name the list does not have makes the project.
move_pick_fzf() {
	self=$(cur_session)
	pane=
	[ -n "$TMUX_REPO" ] && pane=$(slug "$(basename "$TMUX_REPO")")
	[ "$pane" = "${self#*/}" ] && pane=
	out=$({ move_targets "$self"; candidates "${self%%/*}"; } | hoist "$pane" |
		fzf --reverse --no-multi --print-query --prompt "move to ${self%%/*}/")
	case $? in 0 | 1) ;; *) return 0 ;; esac
	name=$(sed -n '2p' <<<"$out")
	[ -n "$name" ] || name=$(sed -n '1p' <<<"$out")
	[ -n "$name" ] || return 0
	move "$name"
}

# --- Driving the bar ------------------------------------------------------
# C-a p h/j/k/l turns the project table into a cursor over the two status rows.
# A step really switches session or window rather than moving a highlight, so row 2
# shows the windows of the project under the cursor and you see what you are about
# to keep. Escape puts back the session and window you came in with, which is why
# both are written down on the way in.
#
# The mode stays open because every step ends with the client back in the nav table.
# Escape, Enter and anything else do not re-arm it, so the table falls back to root
# and the mode is over - see the nav bindings in tmux.conf.
#
# Switching and re-arming are two commands because switch-client does one thing at a
# time: given -T it sets the key table and leaves the session where it was. They run
# in order from here, after tmux has finished with the key, so there is nothing to
# race - tmux resets the table to root as the binding is dispatched, and both of
# these land after that.
NAV_TABLE=nav

# switch-client -T sets the table and returns without a redraw, so the status
# line would keep showing the rows as they were before the step, and the next key
# resets the table to root before anything repaints. refresh-client -S repaints
# the status line now, with the table already nav, so the yellow block shows.
nav_rearm() {
	client=$(cur_client)
	if [ -n "$client" ]; then
		tmux switch-client -c "$client" -T "$NAV_TABLE"
		tmux refresh-client -t "$client" -S
	else
		tmux switch-client -T "$NAV_TABLE"
		tmux refresh-client -S
	fi
}

# Which row the keys are driving. Unset means the project row, the row a fresh
# C-a p h starts on.
nav_row() {
	row=$(tmux show -gv @nav_row 2>/dev/null)
	printf '%s' "${row:-project}"
}

# The project row in bar order: Misc first, then the area's sessions by name, the
# same order the numbers on the bar follow.
nav_projects() {
	printf '%s\n' "$1/$MISC"
	sessions_in "$1"
}

nav_project_step() {
	self=$(cur_session)
	# The project row is a list of one area, so a session without one has no row to
	# walk. The window row is fine either way, which is why the guard sits here
	# rather than on the way into the mode.
	case $self in
	*/*) ;;
	*)
		msg "session '$self' has no area - rename it first, eg: tmux rename-session personal/misc"
		return 0
		;;
	esac
	area=${self%%/*}
	list=$(nav_projects "$area")
	i=$(printf '%s\n' "$list" | grep -nxF "$self" | cut -d: -f1)
	n=$((${i:-1} + $1))
	target=$(printf '%s\n' "$list" | sed -n "${n}p")
	# The ends stop rather than wrap, and the list is one area, so the cursor never
	# crosses from personal to work - the same rule the numbers keep.
	if [ "$n" -lt 1 ] || [ -z "$target" ]; then
		nav_rearm
		return 0
	fi
	# Slot 1 is drawn whether or not a session stands behind it, so arriving there
	# is what finally makes Misc.
	[ "$target" = "$area/$MISC" ] && ensure_misc "$area"
	switch_to "$target"
	nav_rearm
}

nav_window_step() {
	self=$(cur_session)
	list=$(tmux list-windows -t "=$self:" -F '#{window_index}' 2>/dev/null)
	cur=$(tmux display-message -p -t "$(cur_window)" '#{window_index}')
	i=$(printf '%s\n' "$list" | grep -nxF "$cur" | cut -d: -f1)
	n=$((${i:-1} + $1))
	target=$(printf '%s\n' "$list" | sed -n "${n}p")
	if [ "$n" -ge 1 ] && [ -n "$target" ]; then
		tmux select-window -t "=$self:$target"
	fi
	nav_rearm
}

nav_clear() {
	tmux set -gu @nav_origin
	tmux set -gu @nav_row
}

# Escape. The origin session may have been destroyed while you were away - moving
# its last window out does that - so a failed switch is left to say so itself.
nav_cancel() {
	origin=$(tmux show -gv @nav_origin 2>/dev/null)
	nav_clear
	[ -n "$origin" ] || return 0
	switch_to "${origin%% *}"
	tmux select-window -t "${origin##* }" 2>/dev/null
}

nav() {
	case $1 in
	# The row the cursor starts on, and one step to take on arriving, so C-a l moves
	# a window and C-a p l moves a project while both open the same mode. Without a
	# step the mode opens where it is, which is what j and k do from outside it.
	enter)
		tmux set -g @nav_origin "$(cur_session) $(cur_window)"
		tmux set -g @nav_row "$2"
		if [ -n "$3" ]; then
			nav "$3"
		else
			nav_rearm
		fi
		;;
	left)
		if [ "$(nav_row)" = window ]; then nav_window_step -1; else nav_project_step -1; fi
		;;
	right)
		if [ "$(nav_row)" = window ]; then nav_window_step 1; else nav_project_step 1; fi
		;;
	down)
		tmux set -g @nav_row window
		nav_rearm
		;;
	up)
		tmux set -g @nav_row project
		nav_rearm
		;;
	cancel) nav_cancel ;;
	commit) nav_clear ;;
	*) msg "proj.sh nav: unknown step '$1'" ;;
	esac
}

rename() {
	self=$(cur_session)
	name=$(slug "$1")
	[ -n "$name" ] || return 0
	target="${self%%/*}/$name"
	[ "$target" = "$self" ] && return 0
	if tmux has-session -t "=$target" 2>/dev/null; then
		msg "$target already exists"
		return 0
	fi
	tmux rename-session -t "=$self" "$target"
}

move() {
	self=$(cur_session)
	area=${self%%/*}
	name=$(slug "$1")
	[ -n "$name" ] || return 0
	target="$area/$name"
	[ "$target" = "$self" ] && return 0

	# Misc is made the one way, so it keeps @misc_dir. It stands from here on, which
	# also keeps a move into it off the rename branch below.
	[ "$name" = "$MISC" ] && ensure_misc "$area"

	win=$(cur_window)
	if tmux has-session -t "=$target" 2>/dev/null; then
		# The window can always move to a project that already stands. If it was the
		# last one here, tmux takes the empty session with it, which is what leaving
		# a finished project behind looks like.
		tmux move-window -s "$win" -t "=$target:"
	else
		# Making the target out of the only window would empty this project, so tmux
		# would destroy it and the new session would carry a new id, losing its place
		# in the last-project history. One window under a new name is a rename.
		if [ "$(tmux list-windows -t "=$self:" -F x 2>/dev/null | wc -l)" -le 1 ]; then
			rename "$1"
			msg "only window here, so renamed $self to $target instead"
			return 0
		fi
		# new-session insists on a window, so make one, move ours in beside it, and
		# only then kill it - killing the last window would take the session too.
		# -c roots the new project at its repo under the area when there is one,
		# else at the window being spun out, not at wherever tmux happened to
		# default to.
		dir=$(area_dir "$area")/$name
		[ -d "$dir" ] || dir=$(tmux display-message -p -t "$win" '#{pane_current_path}')
		spare=$(tmux new-session -d -P -F '#{window_id}' -s "$target" -c "$dir")
		tmux move-window -s "$win" -t "=$target:"
		tmux kill-window -t "$spare"
	fi
	switch_to "$target"
}

case $1 in
start) start ;;
area) area_flip ;;
bar) bar ;;
goto) goto "$2" ;;
new-prompt) new_prompt ;;
new) new_project "$2" ;;
pick) pick ;;
pick-fzf) pick_fzf ;;
move-pick) move_pick ;;
move-pick-fzf) move_pick_fzf ;;
nav) nav "$2" "$3" "$4" ;;
rename-prompt) rename_prompt ;;
move-prompt) move_prompt ;;
rename) rename "$2" ;;
move) move "$2" ;;
*) msg "proj.sh: unknown command '$1'" ;;
esac
