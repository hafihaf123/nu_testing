# nutest

**The idiomatic, data-driven CLI testing framework for Nushell.**

`nutest` abandons the clunky, procedural DSLs of traditional testing frameworks
(like `describe` and `it`) and fully embraces Nushell's functional, data-passing
architecture. It separates the execution engine from the test definition, providing
a beautifully native testing experience for external binaries and system interactions.

## Key Features

* **Data-Driven by Default:** Define massive testing matrices using standard Nushell
  tables.
* **Native Module Reflection:** Write stateful integration tests using standard
  Nu modules and JSDoc-style docstring tags (`# @test`)—zero parser fighting, perfect
  IDE support.
* **The Fat Output Schema:** All tests output a standardized, strongly-typed Nushell
  record containing the full execution context, untouched system output, and assertion
  history.
* **Pipeline Tooling:** View beautiful terminal diffs or export to CI/CD platforms
  by simply piping your test results into `nutest view` or `nutest export` commands.

## Quick Start

To use `nutest` in your project, simply clone the repository and `use` the module
in your scripts:

```nu
use path/to/nutest *
```

### Pillar 1: The Matrix API (`run-table`)

Perfect for rapidly testing predictable CLI inputs mapped to expected outputs.

```nu
# Define your tests as pure data
let cli_tests = [
    [ name,                  args,           code,  stderr           ];
    [ "empty run",           [],             0,     null             ]
    [ "missing args",        ["--lint"],     1,     "missing input"  ]
]

# Run the table and pipe to the summary viewer
$cli_tests | run-table "./my_app" | nutest view summary
```

### Pillar 2: The Module API (`run-suite`)

Designed for complex, stateful integration tests and multi-step lifecycles.

```nu
# file: my_suite.nu
use nutest [run-cmd, assert]

# @before-each
def setup_test [] {
    { target_dir: (mktemp -d) }
}

# @test
def "compiles standard file" [state: record] {
    run-cmd "./my_app" ["--out" $state.target_dir] 
    | assert code 0
    | assert stderr empty
}
```

Execute the suite module from your terminal or master test script:

```bash
nutest run-suite ./my_suite.nu | nutest export quickfix | save errors.qf
```

## Documentation

The framework is highly extensible and provides powerful tools for debugging, state
management, and CI/CD integration.

For full details, please refer to the documentation in the `docs/` directory:

* [**API Reference (`docs/api.md`)**](./docs/api.md): Detailed specifications for
  the Core Engine, the Matrix API, the Module API, and the Fat Output Schema.
* [**Tooling & Workflows (`docs/tooling.md`)**](./docs/tooling.md): A guide to the
  pipeline tools (`nutest view`, `nutest export`, `nutest dev`) and how to integrate
  them into your daily development loop.
