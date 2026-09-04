export def main []: table -> table {
    const fail_statuses = [
        "FAIL"
        "PANIC"
        "SETUP_PANIC"
        "TEARDOWN_PANIC"
        "TIMEOUT"
    ]

    $in | where status in $fail_statuses
}
