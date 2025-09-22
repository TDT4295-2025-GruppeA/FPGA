import sys
import os

import jinja2

DIR_TESTS = "testtools/stubs"
DIR_TOOLS = "testtools"

abs_path = os.path.abspath(".")
test_path = os.path.join(abs_path, DIR_TESTS)
sys.path.insert(0, abs_path)
sys.path.insert(0, test_path)

def main(modules):
    env = jinja2.Environment(loader=jinja2.FileSystemLoader(DIR_TOOLS))
    template = env.get_template("stub_dummytests.py.jinja2")
    testrunner = template.render(modules=modules)
    with open(f"{DIR_TOOLS}/stub_dummytests.py", "w") as f:
        f.write(testrunner)

if __name__ == "__main__":
    modules = sys.argv[1:]
    main(modules)