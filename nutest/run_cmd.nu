use schema.nu

export def run-cmd [
    binary: string        # Name/path of the executable
    args?: list<string>   # Optional positional arguments (default: [])
    --env-vars: record    # Environment variables to pass (default: {})
    --cwd: directory      # Working directory for execution
    --timeout: duration   # Fails if execution exceeds this limit (default: 10sec)
]: string -> record, nothing -> record {
    let stdin = $in
    let timeout = $timeout | default 10sec
    let cwd = $cwd | default '.' | path expand
    let env_vars = $env_vars | default {}
    let args = $args | default []

    let context = schema context $binary --cwd $cwd --stdin $stdin --args $args --env-vars $env_vars

    let timeout_sec: int = $timeout / 1sec

    let timeout_bin: string = if $env has TIMEOUT_BIN {
        if (which $env.TIMEOUT_BIN | is-not-empty) {
            $env.TIMEOUT_BIN
        } else {
            error make --unspanned {msg: $"Binary/command specified with '$env.TIMEOUT_BIN' was not found: '($env.TIMEOUT_BIN)'"}
        }
    } else if (which timeout | is-not-empty) {
        "timeout"
    } else if (which gtimeout | is-not-empty) {
        "gtimeout"
    } else {
        error make --unspanned {msg: "No 'timeout' or 'gtimeout' command found", help: "You can install GNU coreutils to install the 'timeout' binary, or give the correct path to the timeout binary in the '$env.TIMEOUT_BIN' environment variable"}
    }

    cd $cwd

    let output: record<stdout: string stderr: string exit_code: int> = with-env ($env_vars) {
        $stdin | ^$timeout_bin $timeout_sec $binary ...$args | complete
    }

    let schema = $context | schema output $output.exit_code $output.stdout $output.stderr

    if $output.exit_code == 124 {
        $schema | schema status "TIMEOUT"
    } else {
        $schema
    }
}
