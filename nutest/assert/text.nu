use ../schema.nu
use core.nu run-assert

def "matcher exact" [expected: string]: string -> bool {
    $in == $expected
}

def "matcher contains" [expected: string, --ignore-case(-i)]: string -> bool {
    $in | str contains --ignore-case=$ignore_case $expected
}

def "matcher match" [expected: string]: string -> bool {
    $in =~ $expected
}

export def "stdout exact" [expected: string, --not] {
    run-assert --not=$not $expected {|$ex: string|
        $in.output.stdout | matcher exact $ex
    } "stdout exact"
}

export def "stdout contains" [expected: string, --ignore-case(-i), --not] {
    run-assert --not=$not $expected {|ex: string|
        $in.output.stdout | matcher contains --ignore-case=$ignore_case $ex
    } "stdout contains"
}

export def "stdout match" [expected: string, --not] {
    run-assert --not=$not $expected {|$ex: string|
        $in.output.stdout | matcher match $ex
    } "stdout match"
}

export def "stderr exact" [expected: string, --not] {
    run-assert --not=$not $expected {|$ex: string|
        $in.output.stderr | matcher exact $ex
    } "stderr exact"
}

export def "stderr contains" [expected: string, --ignore-case(-i), --not] {
    run-assert --not=$not $expected {|ex: string|
        $in.output.stderr | matcher contains --ignore-case=$ignore_case $ex
    } "stderr contains"
}

export def "stderr match" [expected: string, --not] {
    run-assert --not=$not $expected {|$ex: string|
        $in.output.stderr | matcher match $ex
    } "stderr match"
}
