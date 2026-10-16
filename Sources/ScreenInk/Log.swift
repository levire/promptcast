import os

/// Shared app logger. Read with `/usr/bin/log show --predicate 'subsystem == "dev.screenink"'`.
let log = Logger(subsystem: "dev.screenink", category: "app")
