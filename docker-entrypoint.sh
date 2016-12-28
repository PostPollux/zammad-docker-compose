#!/bin/bash

ZAMMAD_DIR="/home/zammad"
GIT_URL="https://github.com/zammad/zammad.git"
GIT_BRANCH="stable"
RAILS_SERVER="puma"
RAILS_ENV="production"
DEBUG="no"

if [ "$1" = 'zammad' ]; then

    export RAILS_ENV=${RAILS_ENV}

    # check for existing database, else install
    sed -e 's#.*username:.*#  username: postgres#g' -e 's#.*password:.*#  password: \n  host: postgresql\n#g' < config/database.yml.pkgr > config/database.yml
    cd ${ZAMMAD_DIR}
    rake db:migrate
    if [ $? -ne 1 ]; then
	echo "updating zammad..."
	rake db:migrate
	rake searchindex:rebuild
    else
	echo "initializing zammad..."
	rake db:create
	rake db:migrate
	rake db:seed
	rake assets:precompile
	rails r "Setting.set('es_url', 'http://elasticsearch:9200')"
	rake searchindex:rebuild
    fi

    # delte logs & pids
    rm ${ZAMMAD_DIR}/log/*
    rm ${ZAMMAD_DIR}/tmp/pids/*

    # run zammad
    echo "starting zammad..."
    echo "zammad will be accessable on http://localhost in some seconds"
    bundle exec script/websocket-server.rb -b 0.0.0.0 start &
    bundle exec script/scheduler.rb start &

    if [ "${RAILS_SERVER}" == "puma" ]; then
	bundle exec puma -b tcp://0.0.0.0:3000 -e production
    elif [ "${RAILS_SERVER}" == "unicorn" ]; then
	bundle exec unicorn -p 3000 -c config/unicorn.rb
    fi

    if [ "${DEBUG}" == "yes" ]; then
	# keepalive if error
	while true; do
    	    echo "debugging..."
    	    sleep 600
	done
    fi

fi
