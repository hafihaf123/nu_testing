use assert
use assert/matcher.nu
use run_cmd.nu run-cmd
use run_test.nu run-test
use schema.nu

export def run-table [
    suite: string              # Name of the suite of tests created from the table
    binary: string
    --cwd: directory
    --env-vars: record         # Global env variables, overridden by row-specific `env-vars` column
    --matcher: string          # Global default matcher
    --suite-setup: closure     # Runs ONCE before table. Returns $suite_state
    --suite-teardown: closure  # Runs ONCE after table. Takes $suite_state
    --test-setup: closure      # Runs before EVERY test. Takes $test_row, returns $test_state
    --test-teardown: closure   # Runs after EVERY test. Takes $test_state
    --timeout: duration        # Global timeout per test
]: list<record> -> list<record> {
    let table = $in

    let suite_state = try {
        if $suite_setup != null {
            cd ($cwd | default ".")
            do $suite_setup
        }
    } catch {
        return (
            $table | reduce --fold [(
                schema context $binary --cwd $cwd |
                schema status "SETUP_PANIC" |
                schema test-metadata "Suite Setup Failure" (date now) 0ms --suite $suite
            )] {|it, acc|
                $acc | append (
                    schema context $binary
                        --cwd $cwd
                        --env-vars ($it.env_vars? | default $env_vars | default {})
                        --args $it.args?
                        --stdin $it.stdin? |
                    schema test-metadata $it.name (date now) 0ms --suite $suite |
                    schema status "SKIP"
                )
            }
        )
    }

    let fat_schema = $table | each {|row|
        let name: string = $row.name
        let args: list<string> = $row.args? | default []
        let stdin: oneof<string, nothing> = $row.stdin?
        let env_vars: record = $row.env_vars? | default $env_vars | default {}
        let code: oneof<int, nothing> = $row.code?
        let stdout: oneof<string, nothing> = $row.stdout?
        let stderr: oneof<string, nothing> = $row.stderr?
        let matcher: oneof<string, nothing> = $row.matcher? | default $matcher | default "exact"

        let test_closure = {|test_state|
            mut schema = $stdin | run-cmd $binary $args --cwd $cwd --env-vars $env_vars --timeout $timeout

            if ($code != null) {
                $schema = $schema | assert code $code
            }

            let matcher_closure: closure = match $matcher {
                "exact" => {|s| matcher exact $s}
                "contains" => {|s| matcher contains $s}
                "match" => {|s| matcher match $s}
                _ => {
                    $schema = $schema | schema status "PANIC"
                    {||}
                }
            }

            if ($stdout != null) {
                $schema = $schema | assert $"stdout ($matcher)" {|ex|
                    $in.output.stdout | do $matcher_closure $ex
                } $stdout
            }
            if ($stderr != null) {
                $schema = $schema | assert $"stderr ($matcher)" {|ex|
                    $in.output.stderr | do $matcher_closure $ex
                } $stderr
            }

            $schema
        }

        run-test $name $test_closure --suite $suite --setup $test_setup --teardown $test_teardown --suite-state $suite_state
    }

    try {
        if $suite_teardown != null {
            cd ($cwd | default ".")
            do $suite_teardown $suite_state
        }
    } catch {
        return (
            $fat_schema | append (
                schema context $binary --cwd $cwd |
                schema status "TEARDOWN_PANIC" |
                schema test-metadata "Suite Teardown Failure" (date now) 0ms --suite $suite
            )
        )
    }

    $fat_schema
}
