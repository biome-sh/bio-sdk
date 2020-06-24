#!{{pkgPathFor "core/bash"}}/bin/bash
# -*- mode: shell-script -*-
# shellcheck shell=bash

set -e

PG_LEADER_P='{{svc.me.leader}}'
PG_LEADER_HOST='{{svc.first.sys.hostname}}'
PG_LEADER_PORT='{{cfg.main.port}}'

PG_FOLLOWER_P='{{svc.me.follower}}'

PG_MEMBER_ID="{{svc.me.member_id}}"

PG_DATA_PATH="{{pkg.svc_data_path}}/pgdata"
PG_ARCHIVE_PATH="{{pkg.svc_data_path}}/archive"
PG_PORT="{{cfg.main.port}}"
PG_PID_FILE="{{pkg.svc_var_path}}/postgresql.pid"

USER_SUPERUSER_NAME="{{cfg.user.superuser.name}}"
USER_SUPERUSER_PASSWORD="{{cfg.user.superuser.password}}"
USER_SUPERUSER_OLDPASSWORD="{{cfg.user.superuser.oldpassword}}"

USER_REPLICATION_NAME="{{cfg.user.replication.name}}"
USER_REPLICATION_PASSWORD="{{cfg.user.replication.password}}"

USER_REWIND_NAME="{{cfg.user.rewind.name}}"
USER_REWIND_PASSWORD="{{cfg.user.rewind.password}}"

USER_BACKUP_NAME="{{cfg.user.backup.name}}"
USER_BACKUP_PASSWORD="{{cfg.user.backup.password}}"

USER_DGP_NAME="{{cfg.user.dgp.name}}"
USER_DGP_PASSWORD="{{cfg.user.dgp.password}}"

USER_APPLICATION_NAME="{{cfg.user.application.name}}"
USER_APPLICATION_PASSWORD="{{cfg.user.application.password}}"
USER_APPLICATION_DATABASES='{{strJoin cfg.user.application.databases " "}}'

INITDB_ENCODING="{{cfg.initdb.encoding}}"
INITDB_LOCALE="{{cfg.initdb.locale}}"

# Export variables for libpq
export PGPORT="$PG_PORT"
export PGUSER="$USER_SUPERUSER_NAME"
export PGPASSWORD="$USER_SUPERUSER_PASSWORD"

ensure_user_superuser() {
    if [[ -f "$PG_DATA_PATH/standby.signal" ]]; then
        echo "Skip superuser password set: readonly transaction"
        return 0
    fi

    if [[ -z "$USER_SUPERUSER_OLDPASSWORD" ]]; then
        echo "Skip superuser password set: old password is not provided"
        return 0
    fi

    PGPASSWORD="$USER_SUPERUSER_OLDPASSWORD" psql -q -w -c "ALTER ROLE $USER_SUPERUSER_NAME WITH PASSWORD '$USER_SUPERUSER_PASSWORD';" postgres
    echo "Superuser password set."
}

ensure_user_replication() {
    if [[ -f "$PG_DATA_PATH/standby.signal" ]]; then
        echo "Skip replication user set: readonly transaction"
        return 0
    fi

    psql -q -w -c "ALTER ROLE $USER_REPLICATION_NAME WITH REPLICATION LOGIN PASSWORD '$USER_REPLICATION_PASSWORD';" postgres ||
        psql -q -w -c "CREATE ROLE $USER_REPLICATION_NAME WITH REPLICATION LOGIN PASSWORD '$USER_REPLICATION_PASSWORD';" postgres

    echo "Replication user set."
}

ensure_user_rewind() {
    if [[ -f "$PG_DATA_PATH/standby.signal" ]]; then
        echo "Skip rewind user set: readonly transaction"
        return 0
    fi

    psql -q -w -c "ALTER ROLE $USER_REWIND_NAME WITH NOCREATEDB NOCREATEROLE LOGIN PASSWORD '$USER_REWIND_PASSWORD';" postgres ||
        psql -q -w -c "CREATE ROLE $USER_REWIND_NAME WITH NOCREATEDB NOCREATEROLE LOGIN PASSWORD '$USER_REWIND_PASSWORD';" postgres

    echo "Rewind user set."

    psql -q -w -c "
    GRANT EXECUTE ON function pg_catalog.pg_ls_dir(text, boolean, boolean) TO $USER_REWIND_NAME;
    GRANT EXECUTE ON function pg_catalog.pg_stat_file(text, boolean) TO $USER_REWIND_NAME;
    GRANT EXECUTE ON function pg_catalog.pg_read_binary_file(text) TO $USER_REWIND_NAME;
    GRANT EXECUTE ON function pg_catalog.pg_read_binary_file(text, bigint, bigint, boolean) TO $USER_REWIND_NAME;" postgres

    echo "Rewind user permissions set"
}

ensure_user_backup() {
    if [[ -f "$PG_DATA_PATH/standby.signal" ]]; then
        echo "Skip backup user set: readonly transaction"
        return 0
    fi

    psql -q -w -c "ALTER ROLE $USER_BACKUP_NAME WITH SUPERUSER NOCREATEDB NOCREATEROLE LOGIN PASSWORD '$USER_BACKUP_PASSWORD';" postgres ||
        psql -q -w -c "CREATE ROLE $USER_BACKUP_NAME WITH SUPERUSER NOCREATEDB NOCREATEROLE LOGIN PASSWORD '$USER_BACKUP_PASSWORD';" postgres

    echo "Backup user set."
}

ensure_user_dgp() {
    if [[ -f "$PG_DATA_PATH/standby.signal" ]]; then
        echo "Skip Data Governance Program user set: readonly transaction"
        return 0
    fi

    psql -q -w -c "ALTER ROLE $USER_DGP_NAME WITH NOCREATEDB NOCREATEROLE LOGIN PASSWORD '$USER_DGP_PASSWORD';" postgres ||
        psql -q -w -c "CREATE ROLE $USER_DGP_NAME WITH NOCREATEDB NOCREATEROLE LOGIN PASSWORD '$USER_DGP_PASSWORD';" postgres

    echo "Data Governance Program user set."

    psql -q -w -c "GRANT SELECT ON pg_catalog.pg_class, pg_catalog.pg_namespace, pg_catalog.pg_attribute, pg_catalog.pg_index, pg_catalog.pg_constraint TO $USER_DGP_NAME;" postgres

    echo "Data Governance Program user permissions granted."
}

ensure_user_application() {
    if [[ -f "$PG_DATA_PATH/standby.signal" ]]; then
        echo "Skip application user set: readonly transaction"
        return 0
    fi

    psql -q -w -c "ALTER ROLE $USER_APPLICATION_NAME WITH NOSUPERUSER NOCREATEDB NOCREATEROLE LOGIN PASSWORD '$USER_APPLICATION_PASSWORD';" postgres ||
        psql -q -w -c "CREATE ROLE $USER_APPLICATION_NAME WITH NOSUPERUSER NOCREATEDB NOCREATEROLE LOGIN PASSWORD '$USER_APPLICATION_PASSWORD';" postgres

    echo "Application user set."

    for db in $USER_APPLICATION_DATABASES; do
        psql -q -w -c "GRANT ALL PRIVILEGES ON DATABASE $db TO $USER_APPLICATION_NAME;" postgres

        echo "Application user permissions to $db set."
    done
}

ensure_directories() {
    echo "Ensuring directories."
    mkdir -p "$PG_DATA_PATH" "$PG_ARCHIVE_PATH"

    echo "Ensuring group ownership."
    chgrp -RL "$(id -g)" "$PG_DATA_PATH" "$PG_ARCHIVE_PATH"

    echo "Ensuring access mode."
    chmod 0700 "$PG_DATA_PATH" "$PG_ARCHIVE_PATH"
}

ensure_connection() {
    if [[ -z "$USER_SUPERUSER_OLDPASSWORD" ]]; then
        psql -q -w -c ";" postgres
    else
        PGPASSWORD="$USER_SUPERUSER_OLDPASSWORD" psql -q -w -c ";" postgres
    fi

    echo "Postgres connection set."
}

maybe_create_databases() {
    if [[ -f "$PG_DATA_PATH/standby.signal" ]]; then
        echo "Skip databases creation: readonly transaction"
        return 0
    fi

    for db in $USER_APPLICATION_DATABASES; do
        psql -q -w -c ";" "$db" ||
            createdb -w -E "$INITDB_ENCODING" -l "$INITDB_LOCALE" "$db"
        echo "Database $db set."
    done
}


ensure_replication_slots() {
    if [[ -f "$PG_DATA_PATH/standby.signal" ]]; then
        echo "Skip replication slot creation: readonly transaction"
        return 0
    fi

    # {{#each svc.members as |member| ~}} {{#if member.leader}}
    echo "Remove leader replication slot: {{member.member_id}}"
    psql -q -w -c "select pg_drop_replication_slot('{{member.member_id}}')" postgres || true
    # {{/if}} {{#if member.follower}}
    echo "Create follower replication slot: {{member.member_id}}"
    psql -q -w -c "select pg_create_physical_replication_slot('{{member.member_id}}', true)" postgres || true
    # {{/if}} {{/each}}
}

maybe_pg_initdb() {
    if [[ "$PG_FOLLOWER_P" == "false" ]] && [[ ! -f "$PG_DATA_PATH"/PG_VERSION ]]; then
        echo "Database does not exist, creating with 'initdb'"
        initdb --username "$USER_SUPERUSER_NAME" \
               --pwfile <(echo "$USER_SUPERUSER_PASSWORD") \
               --pgdata "$PG_DATA_PATH" \
               --encoding "$INITDB_ENCODING" \
               --locale "$INITDB_LOCALE" \
               --data-checksums
    fi
}

maybe_pg_basebackup() {
    if [[ "$PG_LEADER_P" == "true" ]]; then
        echo 'I am the leader, skipping base backup.'
        return 0
    fi

    if [[ "$PG_FOLLOWER_P" == "false" ]]; then
        echo "I am not the follower, skipping base backup."
        return 0
    fi

    if [[ -f "$PG_DATA_PATH"/PG_VERSION ]]; then
        echo 'PG_VERSION file exists, skipping base backup.'
        return 0
    fi

    echo "Starting base backup from $PG_LEADER_HOST"

    PGPASSWORD="$USER_REPLICATION_PASSWORD" pg_basebackup \
              --pgdata="$PG_DATA_PATH" \
              --wal-method=stream \
              --progress \
              --verbose \
              --host="$PG_LEADER_HOST" \
              --port="$PG_LEADER_PORT" \
              --username="$USER_REPLICATION_NAME" \
              --no-password
}

maybe_pg_promote() {
    if [[ "$PG_LEADER_P" == "false" ]]; then
        echo "Not a leader, refusing to promote."
        return 0
    fi

    if [[ ! -f "$PG_DATA_PATH"/standby.signal ]]; then
        echo "No standby.signal, nothing to promote."
        return 0
    fi

    echo "Promoting standby to master"
    pg_ctl -D "$PG_DATA_PATH" promote
}

maybe_pg_reload() {
    if [[ ! -f "$PG_DATA_PATH"/postmaster.pid ]]; then
        echo "No postmaster.pid, nothing to reload."
        return 0
    fi

    echo "Reloading database"
    pg_ctl -D "$PG_DATA_PATH" reload
}

maybe_exec_leader() {
    if [[ "$PG_LEADER_P" == "true" ]]; then
        echo "Starting MASTER {{pkg.ident}}"
        exec postgres -c config_file="{{pkg.svc_config_path}}/postgresql.conf"
    fi
}

maybe_exec_follower() {
    if [[ "$PG_FOLLOWER_P" == "true" ]]; then
        touch "{{pkg.svc_data_path}}/pgdata/standby.signal"

        echo "Starting HOTSTANDBY {{pkg.ident}}"
        exec postgres -c config_file="{{pkg.svc_config_path}}/postgresql.conf"
    fi
}

maybe_exec_standalone() {
    if [[ "$PG_LEADER_P" == "false" ]] && [[ "$PG_FOLLOWER_P" == "false" ]]; then
        echo "Starting STANDALONE {{pkg.ident}}"
        exec postgres -c config_file="{{pkg.svc_config_path}}/postgresql.conf"
    fi
}

local_lsn_position() {
    psql -U "{{cfg.user.superuser.name}}" -h localhost -p "{{cfg.main.port}}" -w postgres -t <<EOF | tr -d '[:space:]'
SELECT CASE WHEN pg_is_in_recovery()
  THEN GREATEST(pg_wal_lsn_diff(COALESCE(pg_last_wal_receive_lsn(), '0/0'), '0/0')::bigint,
                pg_wal_lsn_diff(pg_last_wal_replay_lsn(), '0/0')::bigint)
  ELSE pg_wal_lsn_diff(pg_current_wal_lsn(), '0/0')::bigint
END;
EOF
}
