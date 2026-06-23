use ../schema.nu

export def run-assert [
    compare: closure
    matcher: string
    expected?
    --not
]: record -> record {
    let schema = $in

    let passed_raw: bool = $schema | do $compare $expected
    let passed = if $not { not $passed_raw } else { $passed_raw }

    let matcher = if $not { $"not ($matcher)" } else { $matcher }

    $schema | schema assertion $matcher $expected $passed
}
