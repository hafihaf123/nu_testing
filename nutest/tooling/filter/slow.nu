export def main [--threshold: duration]: table -> table {
    let threshold = $threshold | default 5sec
    $in | where metadata?.duration? >= $threshold
}
