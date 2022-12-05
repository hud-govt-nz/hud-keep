from setuptools import setup, find_packages
setup(
    name="hudkeep",
    version="0.5.0",
    description="HUD store/retrieve functions",
    url="https://github.com/hud-govt-nz/hud-keep",
    author="Keith Ng",
    author_email="keith.ng@hud.govt.nz",
    packages=["hudkeep"],
    include_package_data=True,
    install_requires=["python-magic", "azure-storage-blob", "azure-identity"]
)
