export use basic.nu *
export use text.nu *
use core.nu run-assert

export def main [name: string, expected, compare: closure]: record -> record {
    run-assert $expected $compare $name
}
