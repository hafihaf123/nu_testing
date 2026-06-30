export def "exact" [expected: string]: string -> bool {
    $in == $expected
}

export def "contains" [expected: string, --ignore-case(-i)]: string -> bool {
    $in | str contains --ignore-case=$ignore_case $expected
}

export def "match" [expected: string]: string -> bool {
    $in =~ $expected
}
