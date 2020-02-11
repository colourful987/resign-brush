from setuptools import setup, find_packages

setup(
    name='resign-brush',
    version='1.0.0',
    author='pmst',
    author_email='mcxcode@163.com',
    # url='https://',
    packages=find_packages(),
    package_data={'': ['cert/*', 'bin/*.sh']},
    install_requires=[
    ],
    python_requires=">=3.6",
    entry_points={'console_scripts': [
        'resign-brush = resign_brush:brush_entry',
    ]}

)
