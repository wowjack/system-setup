PACKAGE_NAME = "python3-pip"

PIP_PACKAGES = [
    "pandas"
]

from util import run
def customize():
    for package in PIP_PACKAGES:
    	run(["pip", "install", package])
