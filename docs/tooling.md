# Tooling Ecosystem & Workflows

The testing framework is built entirely on the philosophy of **Data-Driven Pipelines**.
Unlike traditional testing frameworks that immediately print colored text to your
terminal, the core execution engines (`suite` and `run-table`) output raw, structured
Nushell data (a list of records).

To interact with this data, you use the framework's tooling commands. These tools
act as pipeline filters and formatters, allowing you to easily view results, export
to CI/CD systems, or debug failures without ever needing to parse raw text.

This document outlines the four logical categories of the tooling ecosystem and
how to use them in your daily workflow.

## The Core Philosophy: The Fat Schema

Before using the tools, it is important to understand what they consume. Every
test run produces a stream of records containing the complete context of the test.

```nu
# A simplified look at what `run-table` or `suite` actually outputs
[
  {
    metadata: { name: "missing semicolon", file: "tests.nu", ... },
    status: "FAIL",
    context: { binary: "./app", args: ["--lint"], env: {}, stdin: null },
    output: { exit_code: 1, stdout: "", stderr: "error..." },
    assertions: [ ... ]
  }
]
```

Because the output is structured, you can use native Nushell commands like `where
status == "FAIL"` before passing the data to the tools below.

## 1. Viewers (`nutest view`)

**Purpose:** To format raw test data into human-readable terminal output.

Viewers consume the test result table and print stylized text. You will use these
constantly to understand test outcomes.

* `nutest view basic`: The default viewer. Prints a simple, clean checklist of
  passing and failing tests with minimal error output.
* `nutest view diff`: Ideal for text-matching assertions. If an `exact` or `contains`
  assertion fails, this viewer cross-references the expected value with the actual
  output and prints a colorized, inline diff showing exactly which characters mismatched.
* `nutest view summary`: Suppresses all individual test logs. It only prints the
  final tallies (total passed, failed, skipped) and the total execution time.

**Workflow Example:**

```nu
# Run the tests, filter for failures, and view the exact text differences
run-table $lint_tests "./crust"
| where status == "FAIL"
| nutest view diff
```

## 2. Exporters (`nutest export`)

**Purpose:** To translate the internal test data into industry-standard formats
for external systems.

Exporters bridge the gap between Nushell and your broader development environment,
such as CI/CD pipelines or text editors.

* `nutest export junit`: Converts the test results into the standard JUnit XML
  format. This is required by platforms like GitHub Actions, GitLab CI, and Jenkins
  to natively display test reports in their web interfaces.
* `nutest export quickfix`: Flattens test failures into a standard `file:line:message`
  text format. This is designed to be piped into a file and read by terminal editors
  (like Neovim/Vim via `:cfile`) so you can instantly jump to the failing test definitions
  using keyboard shortcuts.

**Workflow Example:**

```nu
# Export failures to a quickfix file, then open Neovim with that list loaded
nu tests.nu | nutest export quickfix | save -f errors.qf
nvim -q errors.qf
```

## 3. Developer Utilities (`nutest dev`)

**Purpose:** To assist with the active coding and debugging loop.

These tools do not format results; they use the test context to generate commands,
update test scripts, or manage execution state.

* `nutest dev repro`: Takes a single failing test record and outputs an exact, executable
  shell one-liner. This command perfectly reconstructs the `cwd`, environment variables,
  arguments, and `stdin` so you can copy-paste it directly into a debugger like
  `gdb` or `lldb`.
* `nutest dev snapshot`: An automation tool for the Data-Table API. If your binary's
  output changes intentionally, this tool reads the fresh `raw_output` and automatically
  rewrites your `.nu` test scripts to update the expected values.
* `nutest dev watch`: A wrapper that monitors your project directory for file changes,
  automatically clearing the terminal and rerunning the test pipeline upon saving.

**Workflow Example:**

```nu
# Extract the exact shell command to reproduce the first failing test
$results
| where status == "FAIL"
| first
| nutest dev repro

# Expected Output: RUST_BACKTRACE=1 ./target/debug/crust main.cr
```

## 4. Selectors (`nutest select`)

**Purpose:** To filter the test matrix *before* execution to save time.

When working on a massive codebase, running the entire suite can be slow. Selectors
help you narrow down the execution context interactively.

* `nutest select interactive`: Reads your `tests.nu` script, parses all available
  test names and suites, and opens an interactive terminal UI (TUI). You use the
  arrow keys and spacebar to select exactly which tests to run. The selected subset
  is then passed into the execution engine.

**Workflow Example:**

```nu
# Interactively choose tests, run them, and print the summary
nutest select interactive tests.nu
| run-suite "My App"
| nutest view summary
```
