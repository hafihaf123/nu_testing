# `nutest` API Reference

Welcome to the `nutest` API documentation. `nutest` is an idiomatic, data-driven
CLI testing framework for Nushell.

To maximize ergonomics and respect Nushell's functional design, the framework is
divided into two distinct pillars:

1. **The Matrix API (`run-table`)**: For rapid, boilerplate-free testing of inputs
   against expected outputs.
2. **The Module API (`run-suite`)**: For complex, stateful integration testing using
   standard Nushell modules.

Both pillars are powered by the same core execution primitives and generate the
exact same structured output for downstream tooling.

## Core Primitives (The Engine)

All test executions are driven by these pipeline commands. They can be used inside
Matrix tables, inside Module tests, or directly in the REPL.

### `run-cmd`

Executes an external binary, isolates system IO, and translates the execution into
an internal Nushell record.

**Signature:**

```nu
def run-cmd [
    binary: string        # Name/path of the executable
    args?: list<string>   # Optional positional arguments (default: [])
    --env-vars: record    # Environment variables to pass (default: {})
    --cwd: directory      # Working directory for execution
    --timeout: duration   # Fails if execution exceeds this limit (default: 10sec)
]
```

### `assert` (Pipeline Filters)

Evaluates the output of `run-cmd`. If the assertion passes, it returns the record
unmodified, allowing infinite chaining. If it fails, it halts the pipeline and records
the error.

**Available Subcommands:**

* `assert code [expected: int]`
* `assert stdout exact [expected: string]`
* `assert stdout contains [expected: string]`
* `assert stdout match [regex: string]`
* `assert stdout empty`
* *(Equivalent filters exist for `stderr`)*

**Example Pipeline:**

```nu
run-cmd "./my_app" ["--version"] | assert code 0 | assert stdout contains "v1.0"
```

#### Custom Assertions

Because the pipeline just passes Nushell records, you can write custom assertions
by reading `$in`:

```nu
def "assert valid-json" [] {
    let res = $in
    try { $res.output.stdout | from json } catch { error make { msg: "Invalid JSON" } }
    $res
}
```

## Pillar 1: The Matrix API (`run-table`)

Use the Matrix API for massive, predictable matrices of inputs and outputs. It relies
on standard Nushell tables.

### Table Specification

Define your tests as a standard `list<record>`. Only the `name` column is required;
omitted columns fall back to defaults.

| Column | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `name` | `string` | **Required** | Identifier for the test. |
| `args` | `list<string>`| `[]` | Arguments to pass to the binary. |
| `stdin` | `string` | `null` | Data to pipe into the command. |
| `env-vars` | `record` | `{}` | Row-specific environment variables. *Overrides global `--env-vars`.* |
| `code` | `int` | `0` | Expected exit code. |
| `stdout` | `string` | `null` | Expected standard output. |
| `stderr` | `string` | `null` | Expected standard error. |
| `matcher` | `string` | `"exact"` | Comparison method (`"exact"`, `"contains"`, `"regex"`). *Overrides global `--matcher`.* |

### `run-table`

The executor runs the matrix. It supports global closures and per-test (per-row)
closures.

**Signature:**

```nu
def run-table [
    binary: string
    --cwd: string
    --env-vars: record         # Global env variables, overridden by row-specific `env-vars` column
    --matcher: string          # Global default matcher
    --suite-setup: closure     # Runs ONCE before table. Returns $suite_state
    --suite-teardown: closure  # Runs ONCE after table. Takes $suite_state
    --test-setup: closure      # Runs before EVERY test. Takes $test_row, returns $test_state
    --test-teardown: closure   # Runs after EVERY test. Takes $test_state
    --timeout: duration        # Global timeout per test
]
```

**Example Execution:**

```nu
let cli_tests = [
    [ name,                  args,           code,  stderr           ];
    [ "empty run",           [],             0,     null             ]
    [ "missing args",        ["--lint"],     1,     "missing input"  ]
]

$cli_tests | run-table "./crust" --matcher "contains" --test-setup { |row|
    let file = $"temp_($row.name | str replace -a ' ' '_').cr"
    touch $file
    { target: $file }
} --test-teardown { |state|
    rm -f $state.target
}
```

## Pillar 2: The Module API (`run-suite`)

Use the Module API for multi-step integration tests, stateful execution, and complex
lifecycles.

A suite is a standard Nushell module (`.nu` file). You mark commands as tests or
lifecycle hooks using **Docstring Tags**.

### Docstring Tags

* `# @before-all`: Runs once per module. Returns `$suite_state`. *(Limit: 1 per
  module)*
* `# @after-all`: Runs once per module. Takes `$suite_state`. *(Limit: 1 per module)*
* `# @before-each`: Runs before every test. Takes `$suite_state`, returns `$test_state`.
  *(Limit: 1 per module)*
* `# @after-each`: Runs after every test. Takes `$test_state`. *(Limit: 1 per module)*
* `# @test`: Marks a command as a test case. Takes `$test_state`.

> [!Note]
> If you need multiple setup steps, you must compose them explicitly inside
> the single allowed `# @before-each` or `# @before-all` hook to prevent state-merging
> ambiguity.

### Writing a Suite Module

```nu
# file: database_suite.nu

use nutest [run-cmd, assert]

# @before-all
def setup_suite [] {
    { global_db: "/tmp/mock.db" }
}

# @after-all
def teardown_suite [suite_state: record] {
    rm -f $suite_state.global_db
}

# @before-each
def setup_test [suite_state: record] {
    let local_file = (mktemp)
    { global_db: $suite_state.global_db, local: $local_file }
}

# @test
#
# Compiles a standard file and inserts the result into the global db
def "compiles and inserts" [test_state: record] {
    run-cmd "./crust" ["--db" $test_state.global_db, $test_state.local]
    | assert code 0
}

# @test
def "aborts on read-only file" [test_state: record] {
    chmod 400 $test_state.local
    run-cmd "./crust" [$test_state.local] | assert code 1
}
```

### Executing a Suite

To run the suite, use the `run-suite` command. It uses reflection to safely discover
your tags, injects the lifecycle states, executes the tests, and outputs the structured
results.

```bash
nutest run-suite ./database_suite.nu
```

## The Output Schema (Fat Schema)

Regardless of whether you use `run-table` or `run-suite`, the framework always returns
a unified `list<record>`. This data is designed to be piped directly into
`nutest view` and `nutest export` downstream tools.

| Field | Type | Description |
| :--- | :--- | :--- |
| `metadata` | `record` | High-level tracking injected by the runner. |
| `status` | `string` | `"PASS"`, `"FAIL"`, `"SETUP_PANIC"`, `"TEARDOWN_PANIC"`, `"TIMEOUT"`, or `"SKIP"`. |
| `context` | `record` | Everything needed to perfectly reproduce the execution. |
| `output` | `record` | The raw, untouched result of the binary execution. |
| `assertions` | `list<record>`| A chronological list of the pipeline filters evaluated. |

**Schema Example:**

```nu
{
    metadata: {
        name: "aborts on read-only file",
        suite: "database_suite",
        file: "tests/database_suite.nu",
        timestamp: 2026-06-20 12:30:00,
        duration: 145ms
    },
    status: "FAIL",
    context: {
        binary: "./target/debug/crust",
        args: ["/tmp/tmp.12345"],
        env-vars: {},
        cwd: "/home/user/projects",
        stdin: null
    },
    output: {
        exit_code: 0,
        stdout: "",
        stderr: ""
    },
    assertions: [
        {
            matcher: "code exact",
            expected: "1",
            passed: false
        }
    ]
}
```
