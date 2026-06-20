# Testing Script API Reference

This document outlines the API for writing test scripts using the Nushell
testing framework. The framework provides two distinct approaches to writing
tests, allowing you to choose the best fit for your binary:

1. **The Suite API**: A flexible, closure-based API designed for complex
integration testing, state management, and multi-step pipeline assertions.

2. **The Data-Table API**: A concise, declarative API designed for rapidly
executing a large matrix of inputs and expected outputs.

Both APIs ultimately return a standardized Nushell table containing the test
results, which can be further piped, saved to JSON, or visualized.

## 1. The Suite API

The Suite API uses Nushell's closures and pipelines to create isolated test
scopes, manage cascading setup/teardown state, and chain assertions.

### `suite`

Groups a set of tests together, manages their execution context, and ensures
lifecycle hooks (setup/teardown) are respected even if individual tests panic.
The `suite` command supports both run-once-per-suite and run-per-test lifecycle
hooks.

**Signature:**

```nu
def suite [
    name: string              # The name of the test suite
    --setup: closure          # Logic to run ONCE BEFORE the suite. Returns a $suite_state record.
    --teardown: closure       # Logic to run ONCE AFTER the suite. Takes the $suite_state.
    --before-each: closure    # Logic to run BEFORE EVERY test. Takes $suite_state, returns $shared_test_state.
    --after-each: closure     # Logic to run AFTER EVERY test. Takes $shared_test_state.
    tests: closure            # The block containing the actual `test` commands. Takes the $suite_state.
]
```

**Example:**

```nu
suite "Database Integration" --setup {
    # Runs once per suite
    mkdir test_db
    { db_path: "test_db", port: 5432 }
} --before-each { |suite_state|
    # Runs automatically before every test
    let temp_file = (mktemp)
    { db_path: $suite_state.db_path, file: $temp_file }
} --after-each { |shared_state|
    # Cleans up automatically after every test
    rm -f $shared_state.file
} --teardown { |suite_state|
    # Runs once at the end of the suite
    rm -rf $suite_state.db_path
} { |suite_state|
    test "initializes correctly" { |shared_state|
        # Tests go here, utilizing the state naturally
    }
}
```

### `test`

Defines the boundary of a single test case within a suite. It supports additive,
test-specific lifecycle hooks for edge cases where the suite's `--before-each` is
not enough.

**Signature:**

```nu
def test [
    description: string   # What this specific test validates
    --setup: closure      # Logic to run BEFORE this specific test (runs after --before-each). Takes $shared_test_state, returns $local_test_state.
    --teardown: closure   # Logic to run AFTER this specific test (runs before --after-each). Takes $local_test_state.
    logic: closure        # The pipeline of commands to execute. Takes $local_test_state (or $shared_test_state if no local setup).
]
```

### `run-cmd`

The core execution engine. It runs an external binary, capturing standard
output, standard error, and the exit code into a structured record. It reads its
`stdin` directly from the Nushell pipeline.

**Signature:**

```nu
def run-cmd [
    binary: string        # Path to the executable
    args?: list<string>   # Ordered list of arguments (optional, defaults to [])
    --env: record         # Key-value pairs for environment variables (default: {})
    --cwd: string         # Working directory for the execution
    --timeout: duration   # Maximum execution time before failing (default: 10sec)
]
```

**Pipeline Input:** `string` (used as `stdin` for the binary).

**Pipeline Output:** A typed record:

```nu
{
    stdout: string
    stderr: string
    exit_code: int
    duration: duration
}
```

### `assert` Subcommands

Pipeline filters that evaluate the output record of `run-cmd`. If the condition
passes, the exact same record is passed down the pipeline, allowing infinite
chaining. If it fails, a structured error is raised.

* `assert code [expected: int]`
* `assert stdout exact [expected: string]`
* `assert stdout contains [expected: string]`
* `assert stdout match [regex: string]`
* `assert stdout empty`
* *(Equivalent subcommands exist for `stderr`)*

**Example Pipeline:**

```nu
"SELECT * FROM users;"
| run-cmd "./my_db_cli" ["--format" "json"]
| assert code 0
| assert stderr empty
| assert stdout contains "John Doe"
```

#### Custom Assertions

Because `run-cmd` simply outputs a Nushell record, you can easily write custom
assertions inside your test script by defining a command that reads `$in`:

```nu
def "assert valid-json" [] {
    let res = $in
    try { $res.stdout | from json } catch { error make { msg: "Invalid JSON output" } }
    $res # Pass the record down the pipeline
}
```

## 2. The Data-Table API

The Data-Table API is designed for simple, bulk testing where you want to test
dozens of inputs against expected outputs without writing boilerplate closures.

### Table Specification

To use this API, define a standard Nushell table/list of records. Only the name
column is strictly required; omitted columns fall back to sensible defaults.

| Column | Type | Default | Description |
| :---- | :---- | :---- | :---- |
| `name` | `string` | **Required** | Identifier/description for the test case. |
| `args` | `list<string>` | `[]` | Arguments to pass to the binary. |
| `stdin` | `string` | `null` | Data to pipe into the command. |
| `env` | `record` | `{}` | Test-specific environment variables. *Overrides global `--env`.* |
| `code` | `int` | `0` | Expected exit code. |
| `stdout` | `string` | `null` | Expected standard output. |
| `stderr` | `string` | `null` | Expected standard error. |
| `matcher` | `string` | `"exact"` | Comparison method (`"exact"`, `"contains"`, `"regex"`). *Overrides global `--matcher`.* |

### `run-table`

Accepts your formatted table from the pipeline, executes each row against the
binary, and aggregates the results. It supports both suite-level and test-level
lifecycle hooks.

**Signature:**

```nu
def run-table [
    binary: string            # Path to the executable being tested
    --cwd: string             # Working directory for the execution
    --env: record             # Global environment variables applied to all tests
    --matcher: string         # Global matching strategy (default: "exact")
    --suite-setup: closure    # Runs ONCE before table execution. Returns a $suite_state record.
    --suite-teardown: closure # Runs ONCE after table execution. Takes $suite_state.
    --test-setup: closure      # Runs before EACH test. Takes the test record, returns $test_state.
    --test-teardown: closure   # Runs after EACH test. Takes $test_state.
    --timeout: duration       # Maximum execution time per test (default: 10sec)
]
```

**Example:**

```nu
let parser_tests = [
    [ name                 stdin         args    code  stderr          matcher    ];
    [ "empty run"          ""            []      0     null            "exact"    ]
    [ "missing semicolon"  "int x = 5"   []      1     "syntax error"  "contains" ]
    [ "experimental mode"  "int x = 5;"  ["-e"]  0     "warning: exp"  "contains" ]
]

# Run the table, applying a global environment variable to all tests, 
# and generating a temporary file for each test.

$parser_tests | run-table "./target/debug/my-parser" --env { RUST_BACKTRACE: "1" } --test-setup { |test|
    let temp_file = $"test_($test.name | str replace ' ' '_').cr"
    touch $temp_file
    { file: $temp_file }
} --test-teardown { |test_state|
    rm $test_state.file
}
```

## 4. The Output Schema (Data Structures)

When you run a test script using the Suite API (`suite`) or the Data-Table
API (`run-table`), the framework returns a standard Nushell table (`list<record>`).
Every row in this table represents a single test execution.

This output is heavily structured so you can pipe it directly into custom visualizers,
CI/CD exporters, or debugging tools without needing to parse text.

> [!WARNING]
> The raw output is not meant to be user-friendly and should be interacted with
> mostly only through additional tooling in this repository.

### Record Specification

| Field | Type | Description |
| :--- | :--- | :--- |
| `metadata` | `record` | High-level tracking information about the test. |
| `status` | `string` | The final outcome: `"PASS"`, `"FAIL"`, `"SETUP_PANIC"`, `"TEARDOWN_PANIC"`, `"PANIC"`, or `"SKIP"`. |
| `context` | `record` | Everything needed to perfectly reproduce the command execution. |
| `output` | `record` | The raw, complete result of the binary execution. |
| `assertions` | `list<record>`| A chronological list of the conditions checked during the test. |

### Schema Example

```nu
{
    # 1. METADATA
    metadata: {
        name: "redundant crate prefix",
        suite: "CRust Lints",            # null if running a standalone table
        file: "tests/lint_tests.nu",     # The source file of the test
        timestamp: 2026-06-20 12:30:00,  # Native Nushell datetime
        duration: 145ms                  # Native Nushell duration
    },

    # 2. STATUS
    status: "FAIL",

    # 3. CONTEXT (Reproduction Data)
    context: {
        binary: "./target/debug/crust",
        args: ["main.cr", "--lint"],
        env: { RUST_BACKTRACE: "1" },
        cwd: "/home/user/projects/crust/tests",
        stdin: null                      # The exact string piped into the binary, if any
    },

    # 4. RAW OUTPUT (Execution Results)
    output: {
        exit_code: 0,
        stdout: "",
        stderr: "warning: unused variable\n"
    },

    # 5. ASSERTIONS (Pipeline History)
    # Note: To prevent data bloat, assertions do not duplicate actual output.
    # Downstream tools cross-reference the `matcher` with the `output` block above.
    assertions: [
        {
            matcher: "code exact",
            expected: "0",
            passed: true
        },
        {
            matcher: "stderr contains",
            expected: "redundant crate::",
            passed: false
        }
    ]
}
```
