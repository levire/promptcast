import os

/// Shared app logger. Read with `/usr/bin/log show --predicate 'subsystem == "dev.promptcast"'`.
let log = Logger(subsystem: "dev.promptcast", category: "app")
