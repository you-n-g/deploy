#!/usr/bin/env python3
"""A bounded back/forward history of the panes visible to each tmux client."""

import argparse
import fcntl
import json
import subprocess


STATE_OPTION = "@jump-history-state"
STATUS_OPTION = "@jump-history-status"
CLIENT_FORMAT = "#{client_name}\t#{client_pid}:#{client_created}\t#{session_id}:.#{pane_id}"


def status_format(histories):
    """Cache a tmux format that selects the viewing client's own position."""
    result = ""
    for identity, state in sorted(histories.items()):
        position, length = state["index"] + 1, len(state["entries"])
        ratio = "{}/{}".format(position, length)
        # At the maximum length, /9 is implicit and only the position is shown.
        label = str(position) if length == 9 else ratio
        result = "#{?#{==:#{client_pid}:#{client_created}," + identity + "}," + label + "," + result + "}"
    return result


class History:
    def __init__(self, socket):
        self.socket = socket

    def tmux(self, *args):
        return subprocess.check_output(
            ["tmux", "-S", self.socket, *args], universal_newlines=True
        ).rstrip("\n")

    def leave(self, state, position, limit):
        """Remember panes left behind, most recent first, for `previous`."""
        recent = [position] + [p for p in state.get("recent", []) if p != position]
        state["recent"] = recent[:limit]

    def observe(self, state, position, limit):
        entries = state["entries"]
        if not entries or entries[state["index"]] != position:
            if entries:
                self.leave(state, entries[state["index"]], limit)
            del entries[state["index"] + 1:]
            entries.append(position)
            state["index"] = len(entries) - 1
        # Reduce the bound without dropping the current position if it is near
        # the start of a forward branch.
        start = max(0, state["index"] - limit + 1)
        state["entries"] = entries[start:start + limit]
        state["index"] -= start

    def switch(self, client, current, target):
        # An external switch-client resets the key table, even while a native
        # -r binding's repeat timer is active. Preserve the table in the same
        # command batch; tmux's existing repeat timer still expires normally.
        table = self.tmux("display-message", "-p", "-c", client, "-t", current,
                          "#{client_key_table}")
        command = ["switch-client", "-c", client, "-t", target]
        if table == "prefix":
            command.extend([";", "switch-client", "-c", client, "-T", "prefix"])
        self.tmux(*command)

    def run(self, action, client):
        # The socket directory is private to this user. All hook/key processes
        # share this lock; state itself dies with the tmux server.
        with open(self.socket + ".jump-history.lock", "a") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            self.update(action, client)

    def update(self, action, client):
        limit_text = self.tmux("show-option", "-gqv", "@jump-history-limit")
        if not limit_text.isdecimal() or not 2 <= int(limit_text) <= 9:
            raise ValueError("@jump-history-limit must be an integer between 2 and 9")
        limit = int(limit_text)
        raw = self.tmux("show-option", "-gqv", STATE_OPTION)
        histories = json.loads(raw) if raw else {}
        clients = {}
        for row in self.tmux("list-clients", "-F", CLIENT_FORMAT).splitlines():
            name, identity, position = row.split("\t")
            clients[name] = (identity, position)

        # Disconnected clients have no history. PID + creation time avoids
        # giving a newly attached terminal the history of a reused TTY name.
        active = {identity for identity, _ in clients.values()}
        histories = {key: value for key, value in histories.items() if key in active}
        for identity, position in clients.values():
            state = histories.setdefault(identity, {"entries": [], "index": -1})
            self.observe(state, position, limit)

        if action != "record":
            if client not in clients:
                raise ValueError("jump-history: client is no longer attached: " + client)
            identity, current = clients[client]
            state = histories[identity]
        if action == "previous":
            # The most recently left pane, whether left by a plain switch or a
            # back/forward jump. Closed panes (e.g. a temporary floating pane)
            # are skipped. Resolve by pane id: it may have moved to another
            # session since.
            live = set(self.tmux("list-panes", "-a", "-F", "#{pane_id}").splitlines())
            current_pane = current.split(":.", 1)[1]
            for position in state.get("recent", []):
                pane = position.split(":.", 1)[1]
                if pane in live and pane != current_pane:
                    print(self.tmux("display-message", "-p", "-t", pane,
                                    "#{session_name}:#{window_index}.#{pane_index}"))
                    break
            else:
                raise ValueError("jump-history: no open previously visited pane for client " + client)
        elif action != "record":
            step = -1 if action == "back" else 1
            live = set(self.tmux(
                "list-panes", "-a", "-F", "#{session_id}:.#{pane_id}"
            ).splitlines())
            index = state["index"] + step
            while 0 <= index < len(state["entries"]):
                target = state["entries"][index]
                # Closed panes and removed session links are normal history
                # entries; skip them instead of switching to another pane.
                if target in live and target != current:
                    self.switch(client, current, target)
                    state["index"] = index
                    self.leave(state, current, limit)
                    break
                index += step
            else:
                end = "oldest" if step < 0 else "newest"
                self.tmux("display-message", "-c", client,
                          "jump-history: already at the " + end + " available visit")

        # Hold the lock through both switching and saving the cursor. Hooks
        # caused by our own jump then see the same position and do not append
        # it or erase the forward branch. Failed switches leave state intact.
        encoded = json.dumps(histories, separators=(",", ":"))
        if encoded != raw:
            self.tmux("set-option", "-g", STATE_OPTION, encoded)
        # Render at history updates, not via a new Python process on every
        # status redraw. Also initialize the cache when reloading unchanged history.
        status = status_format(histories)
        if status != self.tmux("show-option", "-gqv", STATUS_OPTION):
            self.tmux("set-option", "-g", STATUS_OPTION, status)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--socket", required=True)
    parser.add_argument("action", choices=("record", "back", "forward", "previous"))
    parser.add_argument("client", nargs="?")
    args = parser.parse_args()
    if args.action != "record" and not args.client:
        parser.error(args.action + " requires a tmux client name")
    History(args.socket).run(args.action, args.client)


if __name__ == "__main__":
    main()
