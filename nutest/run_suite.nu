def parse-tag [tag: string, max: int = 0]: table -> table {
    let command_scope = $in

    let commands = $command_scope | find $tag --columns [description]

    if $max > 0 and ($commands | length) > $max {
        error make
    }

    $commands
}

def parse-suite-metadata [file: path]: nothing -> record {
    let command_scope = (
        ^nu -c $"
            use ($file) *
            scope commands |
                where type == custom |
                where category != default |
                select name description |
                to nuon
        " | from nuon
    )

    let before_all = $command_scope | parse-tag "@before-all" 1 | get --optional 0
    let after_all = $command_scope | parse-tag "@after-all" 1 | get --optional 0
    let before_each = $command_scope | parse-tag "@before-each" 1 | get --optional 0
    let after_each = $command_scope | parse-tag "@after-each" 1 | get --optional 0
    let tests = $command_scope | parse-tag "@test"

    {
        before_all: $before_all.name?
        after_all: $after_all.name?
        before_each: $before_each.name?
        after_each: $after_each.name?
        tests: ($tests | get name?)
    }
}

def generate-runner [file: path]: record -> string {
    let suite_metadata = $in

    const script_path = path self

    let initial = $"
        use ($script_path | path dirname | path join "run_test.nu") run-test
        use ($file) *

        let suite_state = ($suite_metadata.before_all?)

        let schema = []"

    ($suite_metadata.tests | reduce --fold $initial {|it, acc|
        $acc + " | append " + $"\(
            run-test
                \"($it)\"
                {($it)}
                --setup {|i| $i | ($suite_metadata.before_each?)}
                --teardown {|i| $i | ($suite_metadata.after_each?)}
                --suite-state $suite_state
                --file ($file)
                --suite ($file | path parse | get stem)
        \)"
    }) + " | to nuon\n" + $"$suite_state | ($suite_metadata.after_all?)\n$schema"
}

def execute-runner []: string -> table {
    let code = $in

    ^nu -c $code | from nuon
}

export def run-suite [file: path]: nothing -> table {
    let file = $file | path expand -s

    parse-suite-metadata $file | generate-runner $file | execute-runner
}
