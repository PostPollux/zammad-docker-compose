#!/bin/bash


if [ "$1" = 'zammad-scheduler' ]; then
  # wait for zammad process coming up
  until (echo > /dev/tcp/zammad-railsserver/3000) &> /dev/null; do
    echo "scheduler waiting for zammads railsserver to be ready..."
    sleep 2
  done

  echo "scheduler can access raillsserver now..."

  # start scheduler
  cd ${ZAMMAD_DIR}
  exec gosu ${ZAMMAD_USER}:${ZAMMAD_USER} bundle exec script/scheduler.rb run
fi

if [ "$1" = 'zammad-websocket' ]; then
  # wait for zammad process coming up
  until (echo > /dev/tcp/zammad-railsserver/3000) &> /dev/null; do
    echo "websocket server waiting for zammads railsserver to be ready..."
    sleep 5
  done

  echo "websocket server can access raillsserver now..."

  cd ${ZAMMAD_DIR}
  exec gosu ${ZAMMAD_USER}:${ZAMMAD_USER} bundle exec script/websocket-server.rb -b 0.0.0.0 start
fi

if [ "$1" = 'zammad-railsserver' ]; then

  # wait for postgres process coming up on zammad-postgresql
  until (echo > /dev/tcp/zammad-postgresql/5432) &> /dev/null; do
    echo "zammad railsserver waiting for postgresql server to be ready..."
    sleep 5
  done

  echo "railsserver can access postgresql server now..."

  rsync -a --delete --exclude 'storage/fs/*' ${ZAMMAD_TMP_DIR}/ ${ZAMMAD_DIR}

  cd ${ZAMMAD_DIR}

  # update zammad
  gem update bundler
  bundle install

  # db mirgrate
  bundle exec rake db:migrate &> /dev/null

  if [ $? != 0 ]; then
    echo "creating db & searchindex..."
    bundle exec rake db:create
    bundle exec rake db:migrate
    bundle exec rake db:seed
  fi

  # es config
  bundle exec rails r "Setting.set('es_url', 'http://zammad-elasticsearch:9200')"
  bundle exec rake searchindex:rebuild

  chown -R ${ZAMMAD_USER}:${ZAMMAD_USER} ${ZAMMAD_DIR}

  # run zammad
  echo "starting zammad..."
  echo "zammad will be accessable on http://localhost in some seconds"

  if [ "${RAILS_SERVER}" == "puma" ]; then
    exec gosu ${ZAMMAD_USER}:${ZAMMAD_USER} bundle exec puma -b tcp://0.0.0.0:3000 -e ${RAILS_ENV}
  elif [ "${RAILS_SERVER}" == "unicorn" ]; then
    exec gosu ${ZAMMAD_USER}:${ZAMMAD_USER} bundle exec unicorn -p 3000 -c config/unicorn.rb -E ${RAILS_ENV}
  fi

fi

if [ "$1" = 'zammad-backup' ]; then
  # wait for zammad process coming up
  until (echo > /dev/tcp/zammad-railsserver/3000) &> /dev/null; do
    echo "backup waiting for zammads railsserver to be ready..."
    sleep 2
  done

  while true; do
    TIMESTAMP="$(date +'%Y%m%d%H%M%S')"

    echo "${TIMESTAMP} - backuping zammad..."

    # delete old backups
    test -d ${BACKUP_DIR} && find ${BACKUP_DIR}/*_zammad_*.gz -type f -mtime +${HOLD_DAYS} -exec rm {} \;

    # tar files
    tar -czf ${BACKUP_DIR}/${TIMESTAMP}_zammad_files.tar.gz ${ZAMMAD_DIR}

    #db backup
    pg_dump --dbname=postgresql://postgres@zammad-postgresql:5432/zammad_production | gzip > ${BACKUP_DIR}/${TIMESTAMP}_zammad_db.psql.gz

    # wait until next backup
    sleep ${BACKUP_SLEEP}
  done
fi
