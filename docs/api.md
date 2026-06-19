# **Testing Script API Reference**

This document outlines the API for writing test scripts using the Nushell
testing framework. The framework provides two distinct approaches to writing
tests, allowing you to choose the best fit for your binary:

1. **The Suite API**: A flexible, closure-based API designed for complex
integration testing, state management, and multi-step pipeline assertions.

2. **The Data-Table API**: A concise, declarative API designed for rapidly
executing a large matrix of inputs and expected outputs.

Both APIs ultimately return a standardized Nushell table containing the test
results, which can be further piped, saved to JSON, or visualized.

## **1. The Suite API**

The Suite API uses Nushell's closures and pipelines to create isolated test
scopes, manage setup/teardown state, and chain assertions.

### `suite`

Groups a set of tests together, manages their execution context, and ensures
lifecycle hooks (setup/teardown) are respected even if individual tests panic.

**Signature:**

```nu
def suite [
    name: string         # The name of the test suite
    --setup: closure     # Logic to run BEFORE any tests. Returns a state record.
    --teardown: closure  # Logic to run AFTER all tests. Takes the state record as input.
    tests: closure       # The block containing the actual `test` commands. Takes the state record as input.
]
```

**Example:**

```nu
suite "Database Integration" --setup {
    mkdir test_db
    { db_path: "test_db", port: 5432 }
} --teardown { |state|
    rm -rf $state.db_path
} { |state|
    test "initializes correctly" {
        # Tests go here, utilizing $state
    }
}
```

### `test`

Defines the boundary of a single test case within a suite.

**Signature:**

```nu
def test [
    description: string   # What this specific test validates
    logic: closure        # The pipeline of commands to execute
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

## **2. The Data-Table API**

The Data-Table API is designed for simple, bulk testing where you want to test
dozens of inputs against expected outputs without writing boilerplate closures.

### Table Specification

To use this API, define a standard Nushell table/list of records. Only the name
column is strictly required; omitted columns fall back to sensible defaults.

Column | Type | Default | Description
:---- | :---- | :---- | :----
`name` | `string` | **Required** | Identifier/description for the test case.
`args` | `list<string>` | `[]` | Arguments to pass to the binary.
`stdin` | `string` | `null` | Data to pipe into the command.
`env` | `record` | `{}` | Row-specific environment variables. *Overrides global `--env`.*
`code` | `int` | `0` | Expected exit code.
`stdout` | `string` | `null` | Expected standard output.
`stderr` | `string` | `null` | Expected standard error.
`matcher` | `string` | `"exact"` | Comparison method (`"exact"`, `"contains"`, `"regex"`). *Overrides global `--matcher`.*

### `run-table`

Accepts your formatted table from the pipeline, executes each row against the
binary, and aggregates the results.

**Signature:**

```nu
def run-table [
    binary: string        # Path to the executable being tested
    --cwd: string         # Working directory for the execution
    --env: record         # Global environment variables applied to all rows
    --matcher: string     # Global matching strategy (default: "exact")
    --setup: closure      # Runs before table execution. Returns a state record.
    --teardown: closure   # Runs after table execution. Takes the state record as input.
    --timeout: duration   # Maximum execution time per row (default: 10sec)
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

# Run the table, applying a global environment variable to all tests.
# If a specific row provided an `env` column, it would merge/override the global env.

$parser_tests | run-table "./target/debug/my-parser" --env { RUST_BACKTRACE: "1" }
```

## **3. Execution & Outputs**

Whether you use the Suite API (`suite`) or the Data-Table API (`run-table`), the
final execution returns a unified Nushell table detailing the run.

**Output Schema:**

```nu
[
    {
        test_name: string,
        status: string,       # "PASS" or "FAIL"
        expected: any,        # What the assertion was looking for
        actual: any,          # What the binary actually output
        duration: duration    # How long the test took
    }
]
```

Because the output is structured data, you can seamlessly pipe your test scripts
into other Nushell commands for formatting or CI/CD artifacts:

```nu
nu my_tests.nu | where status == "FAIL" | to json | save failed_tests.json
```
