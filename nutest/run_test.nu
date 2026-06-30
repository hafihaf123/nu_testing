use schema.nu

export def run-test [
    name: string
    test: closure
    --setup: closure
    --teardown: closure
    --suite-state: any
    --file: path
    --suite: string
]: nothing -> record {
    let test_state = try {
        if $setup != null {
            do $setup $suite_state
        }
    } catch {
        return (
            {}
            | schema status "SETUP_PANIC"
            | schema test-metadata $name (date now) 0ms
        )
    }

    let timestamp = date now
    let schema: record = try {
        do $test $test_state
    } catch {
        return ({} | schema status "PANIC" | schema test-metadata $name (date now) 0ms)
    }
    let duration = (date now) - $timestamp

    try {
        if $teardown != null {
            do $teardown $test_state
        }
    } catch {
        return (
            $schema
            | schema status "TEARDOWN_PANIC"
            | schema test-metadata $name (date now) 0ms
        )
    }

    let status: string = if $schema has assertions and ($schema | get assertions | any {not $in.passed}) {
        "FAIL"
    } else {
        "PASS"
    }

    $schema
    | schema status $status
    | schema test-metadata $name $timestamp $duration --file $file --suite $suite
}
