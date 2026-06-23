export use basic.nu *
export use text.nu *
use core.nu run-assert

export def main [name: string, compare: closure, expected?]: record -> record {
    run-assert $compare $name $expected
}
