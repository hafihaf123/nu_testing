export def test-metadata [
    name: string
    timestamp: datetime
    duration: duration
    --suite: string
    --file: path
]: record -> record {
    $in | upsert metadata {
        name: $name
        suite: $suite
        file: ($file | path expand)
        timestamp: $timestamp
        duration: $duration
    }
}

export def context [
    binary: string
    cwd: string
    --stdin: string
    --args: list<string>
    --env-vars: record
]: nothing -> record, record -> record {
    let clean_envs = (
        $env_vars
        | default {}
        | items {|k,v| {$k: ($v | into string)}}
        | into record
    )

    $in | default {} | upsert context {
        binary: $binary
        args: ($args | default [])
        env-vars: $clean_envs
        cwd: $cwd
        stdin: $stdin
    }
}

export def output [exit_code: int, stdout: string, stderr: string]: record -> record {
    $in | upsert output {exit_code: $exit_code, stdout: $stdout, stderr: $stderr}
}

export def assertion [matcher: string, expected, passed: bool]: record -> record {
    $in | upsert assertions (
        $in.assertions?
        | default []
        | append {matcher: $matcher, expected: $expected, passed: $passed}
    )
}

export def status [status: string]: record -> record {
    const allowed_statuses = [
        "PASS"
        "FAIL"
        "SETUP_PANIC"
        "TEARDOWN_PANIC"
        "SKIP"
        "TIMEOUT"
    ]

    if $status not-in $allowed_statuses {
        error make {
            msg: "Status option not recognized"
            help: $"Try one of these: ($allowed_statuses)"
            labels: [
                {
                    text: "Not a valid status string"
                    span: (metadata $status).span
                }
            ]
        }
    }

    $in | upsert status $status
}
