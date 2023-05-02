from setuptools import setup
import os

VERSION = "0.1"

def get_long_description():
    with open(
        os.path.join(os.path.dirname(os.path.abspath(__file__)), "README.md"),
        encoding="utf8",
    ) as fp:
        return fp.read()

setup(
    name="cath-emma",
    description="Workflow to classify CATH domains sequences into CATH Functional Families using embeddings",
    long_description=get_long_description(),
    long_description_content_type="text/markdown",
    author=["Nicola Bordin", "Clemens Rauer", "Ian Sillitoe", "Weining Lin"],
    url="https://github.com/UCLOrengoGroup/cath-emma",
    project_urls={
        "Issues": "TBD",
        "CI": "TBD",
        "Changelog": "TBD",
    },
    license="Apache License, Version 2.0",
    version=VERSION,
    packages=["cath_emma"],
    entry_points="""
        [console_scripts]
        cath-emma-cli=cath_emma.cli:cli
    """,
    install_requires=[
        "click",
        "pandas",
        "fair-esm",
        "torch",
        "tqdm",
        "biopython",
    ],
    extras_require={"test": ["pytest"]},
    python_requires=">=3.7",
)