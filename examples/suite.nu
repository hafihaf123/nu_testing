use ../nutest

# @before-all
export def suite-setup [] {
    {setup: true}
}

# @after-all
export def suite-teardown [] {
    if $in.setup != true {
        error make
    }
}

# @before-each
export def test-setup [] {
    if $in.setup {
        {test_setup: true}
    } else {
        {test_setup: false}
    }
}

# @after-each
export def test-teardown [] {
    if $in.test_setup != true {
        error make
    }
}

# @test
export def "test 1" [] {
    nutest run-cmd "true" | nutest assert code 0
}

# @test
export def "test 2" [] {
    nutest run-cmd "false" | nutest assert code --not 0
}

# @test
export def "failing test" [] {
    nutest run-cmd "echo" ["something\nmulti\nline"]
    | nutest assert stdout exact "something\nmultii\nline\n"
}
