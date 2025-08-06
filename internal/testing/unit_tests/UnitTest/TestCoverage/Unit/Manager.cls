Class UnitTest.TestCoverage.Unit.Manager Extends %UnitTest.TestCase
{

Parameter AutoUserNames As STRING = "TestA;TestB;TestC";

Method TestAutoUserNames()
{
    // verify the 3 usernames are automatically created
    ZNSPACE "%SYS"

    Do $$$AssertTrue(##class(Security.Users).Exists("TestA"))
    Do $$$AssertTrue(##class(Security.Users).Exists("TestB"))
    Do $$$AssertTrue(##class(Security.Users).Exists("TestC"))
    Do $$$AssertNotTrue(##class(Security.Users).Exists("TestD"))
}

}
