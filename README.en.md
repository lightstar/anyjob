# AnyJob

Program system used to run arbitrary jobs on different linux nodes and observe how they run.
By now it is on alpha testing stage, and you should not use it in production.

AnyJob can be used to simplify automation inside your distributed project or to quickly perform some
frequent tasks and request information from the single entry point.

For data storage and communication between different system parts *redis* server is used.

As main programming platform *perl* was choosed. In theory you can develop job modules in any language
you want because workers are run as separate executables but that will require additional support
for each such case.

### Goals

### Basic principles and concept

### Before using

### Browser web application screenshots

**Beginning:**

![Screenshot](img/screenshot1.png)

**Job group and type selected:**

![Screenshot](img/screenshot2.png)

**Job created:**

![Screenshot](img/screenshot3.png)

**Job finished:**

![Screenshot](img/screenshot4.png)

### Limitations and further development plans

