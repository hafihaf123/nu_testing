def parse-tag [tag: string, file_span: record, max: int = 0]: table -> table {
    let command_scope = $in

    let commands = $command_scope | find $tag --columns [description]

    if $max > 0 and ($commands | length) > $max {
        error make {
            msg: "Suite configuration error:"
            labels: [
                {
                    text: $"Expected at most ($max) instance\(s\) of ($tag), but found ($commands | length)."
                    span: $file_span
                }
            ]
        }
    }

    $commands
}

def parse-suite-metadata [file: path, file_span: record]: nothing -> record {
    let command_scope = (
        ^nu --no-config-file -c $"
            use ($file) *
            scope commands |
                where type == custom |
                where category != default |
                select name description |
                to nuon
        " | from nuon
    )

    let before_all = $command_scope | parse-tag "@before-all" $file_span 1 | get --optional 0
    let after_all = $command_scope | parse-tag "@after-all" $file_span 1 | get --optional 0
    let before_each = $command_scope | parse-tag "@before-each" $file_span 1 | get --optional 0
    let after_each = $command_scope | parse-tag "@after-each" $file_span 1 | get --optional 0
    let tests = $command_scope | parse-tag "@test" $file_span

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
    let before_all = $suite_metadata.before_all? | default 'null'
    let before_each = $suite_metadata.before_each? | default 'null'
    let after_each = $suite_metadata.after_each? | default 'null'
    let after_all = $suite_metadata.after_all? | default 'null'

    const script_path = path self

    let initial = $"
        use ($script_path | path dirname | path join "run_test.nu") run-test
        use ($file) *

        let suite_state = ($before_all)

        let schema = []"

    ($suite_metadata.tests | reduce --fold $initial {|it, acc|
        $acc + $" | append \(
            run-test
                \"($it)\"
                {($it)}
                --setup {|i| $i | ($before_each)}
                --teardown {|i| $i | ($after_each)}
                --suite-state $suite_state
                --file ($file)
                --suite ($file | path parse | get stem)
        \)"
    }) + $" | to nuon
        $suite_state | ($after_all)
        $schema
    "
}

def execute-runner []: string -> table {
    let code = $in

    ^nu --no-config-file -c $code | from nuon
}

export def run-suite [file: path]: nothing -> table {
    let file_span = (metadata $file).span
    let file = $file | path expand -s

    parse-suite-metadata $file $file_span | generate-runner $file | execute-runner
}
