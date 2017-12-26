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

The following goals were pursued during system development:

- Maximal configurability, ability to run actually *any* jobs with minimal dependencies on environment and conditions.

- Adding and deployment of new jobs should be as simple as possible.

- Maximal flexibility of job starting and executioning, ability to create set of interrelated jobs which will know
about each other and act in a coordinated manner.

- Maximal flexibility of observing how jobs are run, arbitrary ways to notify end users about it.

### Basic principles and concept

*Job* is entity which must be run on some node. It has *type*, *parameters* and *properties*. All jobs are created
by *creator* component and allowed to unite into interrelated group called *jobset*. Parameters and properties have
similar structure (it's just 'name-value' pairs), but allowed parameters are individual for each job type and
properties are global for the whole system. Parameters are used by *worker* component during job execution, and
properties are used by AnyJob system itself and by observers too.

*Event* is entity which holds information about some movement in job or jobset execution. Events are sent to
*observers*.

*Node* is some physical or virtual server where jobs are run.

*Creator* is a separate component which creates new jobs and jobsets. It can contain arbitrary number of
addons providing different creation methods. By now it supports next ones:
- Using console application *bin/anyjobc.pl*. Just feed to it job type, nodes separated by comma, parameters and
properties in format 'name=value'.
- Using web application. It is started by bash script 'rc.anyjobc' and actually provides two creation ways:
using browser-side application and using slack application (https://slack.com/).

In addition to actual creating creator supports another interesting feature: observing created jobs. Unlike
individual observers creator observes just the jobs it created and can send notifications directly to users who
created them. That embedded into creator observer is called *private* observer.

*Builder* is a inner component of creator which is used to build jobs in several steps. By now it is used only by slack
application.

*Daemon* is a separate component which is a heart of the system, and there are one or more controllers which are run
inside. Daemon is started on each node by bash script 'rc.anyjobd'. There should be *global* controller on one
choosed node which controls entire system including jobsets, and *regular* controller on every node where jobs are
supposed to be run. 

*Observer* is a controller subtype which observes events sent directly to it and it runs inside daemon. Each observer
should exist only in one copy in the whole system. On receiving event observer usually generates some notification
using provided template and sends it to one or more configured recipients (i.e. by mail, into slack channel or just
to log file).

*Worker* is a separate component which performs one specific job. Its executable file is 'bin/anyjobw.pl' by
default, and it is started by daemon automatically. Each job type should have its own module (but that's not required:
one module could support several similar job types). To perform correctly worker should notify AnyJob about job
progress, completion and also probably watch for jobset state if it needs coordinated work. Convenient methods for
every such use case are included in base class 'AnyJob::Worker::Base' which all job modules should extend. 

### Before using

To use AnyJob you need:

- select interconnected server nodes where you want to run jobs, choose names for them (you can use host names
for simplicity).

- install AnyJob on them (read [doc/install.txt](doc/install.txt) for details about prerequisites and installation
steps).

- determine jobs you want to run and create appropriate *perl* modules for them. You can use other language but for
now only for *perl* convenient environment and base class (*AnyJob::Worker::Base*) are available.

- configure AnyJob on each node. Read [doc/config.txt](doc/config.txt) and other documentation files for details.

- to create jobs you can use console utility *bin/anyjobc.pl* or separate web application. Slack application
(https://slack.com) is also available as part of that web application.

- to understand how all works it is extremely recommended to read all documentation from the *doc* directory.
   - [doc/install.txt](doc/install.txt) - prerequisites and installation steps.
   - [doc/env.txt](doc/env.txt) - environment variables.
   - [doc/config.txt](doc/config.txt) - configuration.
   - [doc/event.txt](doc/event.txt) - events and observers.
   - [doc/props.txt](doc/props.txt) - properties of jobs and jobsets.
   - [doc/redis.txt](doc/redis.txt) - keys used in *redis*.

If you plan to extend AnyJob, it is recommended to study code and comments. At least you should examine
*AnyJob::Worker::Base* and *AnyJob::Worker::Example* to understand how to correctly write new job modules.

### Browser web application screenshots

**Beginning:**

![Screenshot](img/screenshot1.png)

**Job group and type are selected:**

![Screenshot](img/screenshot2.png)

**Job is created:**

![Screenshot](img/screenshot3.png)

**Job is finished:**

![Screenshot](img/screenshot4.png)

### Limitations and further development plans

1. Full job support is implemented only for *perl* environment. For all other platforms writing specific
executable, classes etc. is required. Anyway that's not planned for now.

2. There are no automatic tests implemented, all testing is performed only by hand now. It would be nice to implement
them but that's not high priority task.

3. Jobs are now created only by direct specifying their type, nodes, parameters and properties. It would be nice to
specify some abstract type and parameters which will be transformed by creator into real job or jobset data.
For example one could create 'restart_all' job which will transform into 'restart' job on every node, possibly with
some additional jobs.

4. Jobs are now started in separated processes, brand new for every job. It would be nice to have one or more already
running daemon workers which could perform jobs without starting new processes.

5. Configuration is loaded fully by now. Probably that's not good considering its possible growth in the future. So
better think about some 'lazy' loading or just load only really needed configuration in each component. For example
there is no point to load every job configuration in worker component which runs only one specific job.

6. Jobs are now launched right after creation, but it would be nice to have delayed job starting.

7. *Redis* is now used both for data storage and for message queuing. It performs good, but it would be better to
abstract away by using some specific modules to simplify transition to some other mechanisms in future.

8. Http requests and redis queues polling are now performed synchronously, but that potentially could lead to lags
throughout entire system, so better think about making it asynchronous.

9. It would be nice to limit jobs execution using some configured blocks or semaphores. So one could say that
some job can execute only consequentially or only in limited quantity of simultaneously launched copies. By now
it is possible to limit active jobs count only globally.

10. It is worth implementing some common use worker modules 'out of the box'. For example such that would execute
some arbitrary program and intercept its input and output, or run specific method in some perl module with defined
parameters, etc.

11. By now all worker processes are executed under *root* system user. It is worth implementing possibility to specify
user and group under which they will be executed.

12. All messages displayed by applications are only in english now. It would be nice to implement internationalization,
add translations for all messages and possibility to switch between languages (russian is priority of course).

13. By now slack application demands explicit notation of job type and nodes list in slash command text. It is worth
adding possibility to specify group, type and nodes using separate dialogs.

14. It is worth to add support for links leading to partially created jobs in the web application to simplify job
creation.
