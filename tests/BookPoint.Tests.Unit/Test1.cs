using FluentAssertions;
using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace BookPoint.Tests.Unit;

[TestClass]
#pragma warning disable CA1050 // Declare types in namespaces (test visibility)
public sealed class Test1
#pragma warning restore CA1050
{
    [TestMethod]
    public void TestMethod1()
    {
    // trivial smoke assertion to ensure unit tests run in CI
    const int expected = 2;
    (1 + 1).Should().Be(expected);
    }
}
