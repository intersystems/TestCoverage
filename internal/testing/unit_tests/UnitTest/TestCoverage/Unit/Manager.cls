Class UnitTest.TestCoverage.Unit.Manager Extends %UnitTest.TestCase
{

Parameter AutoUserNames As STRING = "TestA;TestB;TestC";

Method TestAutoUserNames()
{
    // verify the 3 usernames are automatically created
    New $NAMESPACE
    Set $NAMESPACE = "%SYS"

    Do $$$AssertTrue(##class(Security.Users).Exists("TestA"))
    Do $$$AssertTrue(##class(Security.Users).Exists("TestB"))
    Do $$$AssertTrue(##class(Security.Users).Exists("TestC"))
    Do $$$AssertNotTrue(##class(Security.Users).Exists("TestD"))
}

Method TestSearchClasses()
{
    set expr = "TestCoverage.DataType.*"
    do ##class(TestCoverage.Manager).SearchClasses(expr, .classes)

    do $$$AssertTrue($data(classes("TestCoverage.DataType.Bitstring")))
    do $$$AssertTrue($data(classes("TestCoverage.DataType.Detail")))
    do $$$AssertTrue($data(classes("TestCoverage.DataType.Metric")))
    do $$$AssertTrue($data(classes("TestCoverage.DataType.RoutineType")))
    do $$$AssertTrue($data(classes("TestCoverage.DataType.Timing")))

    set count = 0
    set node = ""
    for {
        set node = $Order(classes(node))
        quit:node=""
        set count = count + 1
    }
    do $$$AssertEquals(count, 5)
}

}
