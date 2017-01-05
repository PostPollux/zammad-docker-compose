Welcome to Zammad
=================

Zammad is a web based open source helpdesk/ticket system with many features
to manage customer communication via several channels like telephone, facebook,
twitter, chat and e-mails. It is distributed under the GNU AFFERO General Public
 License (AGPL) and tested on Linux, Solaris, AIX, FreeBSD, OpenBSD and Mac OS
10.x. Do you receive many e-mails and want to answer them with a team of agents?
You're going to love Zammad!

What is zammad-docker-compose repo for?
----------------------------------------

If you want to use Zammad in production with docker, you need an environment with all desired services that keep their data persistent.
In contrast to monotek/zammad-docker-compose or the zammad/zammad images, this environment is built in a way that it keeps your data persistent when you update the zammad container from a new image (as it's expected to be done with docker). The monotek/zammad-docker-compose follows the intention, that you never drop, update, remove or replace the running zammad container, as it would delete the database config which is used as a trigger to reinstall zammad => that zammad container will drop your database if you touch the container and not just restart it.

To detect if zammad is connected to a already seeded database, I use the error handling of `rake db:migrate` which will return an exit code 1 if the database is not yet seeded.

Data persistence
-------------------------

I personally prefer mounting storage paths of containers to the local disk instead of using named volumes, but feel free to change that in the `docker-compose.yml`.

Getting started with zammad-docker-compose
------------------------------------------

* sysctl -w vm.max_map_count=262144
* docker-compose up --build

Docs
----

https://docs.zammad.org/en/latest/contributing-install-docker.html
