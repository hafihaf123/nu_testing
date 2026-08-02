export def main []: table -> record {
    let schema = $in

    $schema | reduce --fold {passed: 0 failed: 0 skipped: 0 panics: 0} {|test, acc|
        match $test.status {
            "PASS" => ($acc | update passed ($acc.passed + 1))
            "FAIL" => ($acc | update failed ($acc.failed + 1))
            "SKIP" => ($acc | update skipped ($acc.skipped + 1))
            _ => ($acc | update panics ($acc.panics + 1))
        }
    }
}
