use ../schema.nu
use core.nu run-assert
use matcher.nu

export def "stdout exact" [expected: string, --not] {
    run-assert --not=$not {|$ex: string|
        $in.output.stdout | matcher exact $ex
    } "stdout exact" $expected
}

export def "stdout contains" [expected: string, --ignore-case(-i), --not] {
    run-assert --not=$not {|ex: string|
        $in.output.stdout | matcher contains --ignore-case=$ignore_case $ex
    } "stdout contains" $expected
}

export def "stdout match" [expected: string, --not] {
    run-assert --not=$not {|$ex: string|
        $in.output.stdout | matcher match $ex
    } "stdout match" $expected
}

export def "stderr exact" [expected: string, --not] {
    run-assert --not=$not {|$ex: string|
        $in.output.stderr | matcher exact $ex
    } "stderr exact" $expected
}

export def "stderr contains" [expected: string, --ignore-case(-i), --not] {
    run-assert --not=$not {|ex: string|
        $in.output.stderr | matcher contains --ignore-case=$ignore_case $ex
    } "stderr contains" $expected
}

export def "stderr match" [expected: string, --not] {
    run-assert --not=$not {|$ex: string|
        $in.output.stderr | matcher match $ex
    } "stderr match" $expected
}
