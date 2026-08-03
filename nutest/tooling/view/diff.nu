def format-diff [expected: string, actual: string]: nothing -> string {
    let exp_file = (mktemp -t)
    let act_file = (mktemp -t)

    $expected | save --force $exp_file
    $actual | save --force $act_file

    let result = (
        ^git diff --no-index --color=always $exp_file $act_file 
        | complete
    )

    rm --force $exp_file $act_file

    if ($result.stdout | is-empty) {
        return ""
    }

    let cleaned_diff = (
        $result.stdout
        | lines
        | skip 4
        | str join "\n"
    )

    $cleaned_diff
}

export def main []: table -> nothing {
    let schema = $in

    $schema | where {
        $in.status == 'FAIL' and ($in.assertions | any {$in.matcher =~ 'exact'})
    } | each {|test|
        print $"($test.metadata.suite) |  (ansi red)($test.metadata.name)(ansi reset)"
        $test.assertions | where matcher =~ 'exact' | each {|assertion|
            let actual = match $assertion.matcher {
                'stdout exact' => $test.output.stdout
                'stderr exact' => $test.output.stderr
            }
            let expected = $assertion.expected

            print (format-diff $expected $actual)
        }
        print
    }

    null
}
