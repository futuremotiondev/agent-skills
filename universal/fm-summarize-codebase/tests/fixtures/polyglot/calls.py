import signal


class DebugLogger:
    def enable(self):
        self.on = True

    def record_event(self, event):
        self._append_event(event)

    def _append_event(self, event):
        self.events.append(event)


class Tab:
    def activate_tab(self):
        return self.send("Page.enable")

    def record_event(self, event):
        return event


def attach(tab, debug_logger):
    tab.activate_tab()
    debug_logger.record_event("attached")


def _on_signal(signum, frame):
    pass


def install():
    signal.signal(signal.SIGTERM, _on_signal)


def _unused_helper():
    return 42
