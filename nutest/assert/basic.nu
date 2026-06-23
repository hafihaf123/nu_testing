use ../schema.nu
use core.nu run-assert

export def code [expected_code: int, --not]: record -> record {
    run-assert --not=$not $expected_code {|ex: int|
        $in.output.exit_code == $ex
    } "code"
}

export def timeout []: record -> record {
    let schema = $in
    const matcher = "timeout"

    if $schema.status == "TIMEOUT" {
        $schema | schema status "PASS" | schema assertion $matcher null true
    } else {
        $schema | schema assertion $matcher null false
    }
}
