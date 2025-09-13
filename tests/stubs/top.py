
# Required because of importlib's inability to import .pyi
def __getattr__(name):
    return None
