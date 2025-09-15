def pytest_collection_modifyitems(items):
    """Hacky solution to rename tests away from testrunner.py"""
    for item in items:
        filename = item.keywords["module"].args[0]
        testname = item.keywords["module"].args[2]

        parts = item.nodeid.split("::")
        parts[0] = filename
        parts[1] = testname
        item._nodeid = "::".join(parts)
