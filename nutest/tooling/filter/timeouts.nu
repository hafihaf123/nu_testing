export def main []: table -> table {
    const timeout_status = "TIMEOUT"

    $in | where status == $timeout_status
}
