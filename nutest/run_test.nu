use schema.nu

export def run-test [
    name: string
    test: closure
    --file: path
    --suite: string
]: nothing -> record {
    let timestamp = date now
    let schema: record = try {
        do $test
    } catch {
        return {} | schema status "PANIC"
    }
    let duration = (date now) - $timestamp

    let status: string = if $schema has assertions {
        if ($schema | get assertions | any {not $in.passed}) {
            "FAIL"
        } else {
            "PASS"
        }
    } else {
        "PASS"
    }

    $schema
    | schema status $status
    | schema test-metadata name $timestamp $duration --file $file --suite $suite
}
