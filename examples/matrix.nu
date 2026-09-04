#!/usr/bin/env nu

use ../nutest

let matrix = [
    [name           , args                                    , code , stdout                      ];
    ["test 1"       , ["-c" "true"]                           , 0    , null                        ],
    ["test 2"       , ["-c" "false"]                          , 1    , null                        ],
    ["failing test" , ["-c" "echo 'something\nmulti\nline'"]  , null , "something\nmultii\nline\n" ],
    ["timeout test" , ["-c" "while true; do sleep 0.1; done"] , 0    , null                        ]
]

$matrix | nutest run-table "suite" "bash" | to nuon
