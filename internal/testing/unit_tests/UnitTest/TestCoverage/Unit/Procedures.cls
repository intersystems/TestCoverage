Class UnitTest.TestCoverage.Unit.Procedures Extends %UnitTest.TestCase
{

Method TestListToBit()
{
    Set compare = ""
    For i=1:1:3 {
        Set $Bit(compare,i) = 1
    }
    Do $$$AssertEquals(##class(TestCoverage.Procedures).ListToBit($lb(1,2,3,,"")),compare)
}

}