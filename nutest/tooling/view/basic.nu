use summary.nu

export def main []: table -> record {
    let schema = $in

    $schema | each {|test|
        let status_color = match $test.status {
            "PASS" => (ansi green)
            "FAIL" => (ansi red)
            "SKIP" => (ansi yellow)
            "TIMEOUT" => (ansi purple)
            _ => (ansi red_reverse)
        }

        let icon = match $test.status {
            "PASS" => "✔"
            "FAIL" => "✖"
            "SKIP" => "⏸"
            "TIMEOUT" => "⏱"
            _ => "(!)"
        }

        print $"($status_color)($icon)(ansi reset)  ($test.metadata.suite) |  ($test.metadata.name)"
    }

    $schema | summary
}
