#!/bin/bash

#Схема БД (с точкой)
PG_SCHEMA='fias.'

#Список регионов для загрузки, двузначное значение, как задано в файле ФИАС
declare -a reg_list=("72" "86")

#Данные для подключения к базе данных PG
PG_USER="postgres"
PG_PWD=""
PG_DB=""
PG_HOST='localhost'
PG_PORT='5432'

#export PGUSER=$PG_USER
#export PGPASSWORD=$PG_PWD

# the temp directory used, within dbf_dir
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# the temp directory used, within $SCRIPT_DIR
WORK_DIR=`mktemp -d -p "$SCRIPT_DIR"`

# Удаление временной папки
function cleanup {
  rm -rf "$WORK_DIR"
  echo "Удаление временной папки $WORK_DIR"
}

# register the cleanup function to be called on the EXIT signal
#@trap cleanup EXIT

cd "$WORK_DIR"
#Скачивание файла: целиком или только дельта изменений.
#При загрузке полных данных необъодимо предварительно удалить имеющиеся таблицы вручную!
#wget -O "$WORK_DIR"/fias_dbf.zip http://fias.nalog.ru/Public/Downloads/Actual/fias_dbf.zip
wget -O "$WORK_DIR"/fias_dbf.zip http://fias.nalog.ru/Public/Downloads/Actual/fias_delta_dbf.zip

#Распаковка
unzip -o "$WORK_DIR"/fias_dbf.zip SOCRBASE.DBF
chmod 664 "$WORK_DIR"/SOCRBASE.DBF

for i in "${reg_list[@]}"
do
   unzip -o "$WORK_DIR"/fias_dbf.zip ADDROB"$i".DBF HOUSE"$i".DBF
   chmod 664 "$WORK_DIR"/ADDROB"$i".DBF
   chmod 664 "$WORK_DIR"/HOUSE"$i".DBF
done

echo "Загрузка файла сокращений SOCRBASE.DBF..."
pgdbf -cDp -s cp866 "$WORK_DIR"/SOCRBASE.DBF  | awk '{sub("CREATE TABLE ","CREATE TABLE IF NOT EXISTS '$PG_SCHEMA'"); sub("DROP TABLE IF EXISTS","DROP TABLE IF EXISTS '$PG_SCHEMA'"); sub("'1000-00-00'","1970-01-01"); sub("COPY ","COPY '$PG_SCHEMA'"); sub("timeout=60000","timeout=999999");  print }' | psql -h $PG_HOST -p $PG_PORT -d $PG_DB -U $PG_USER
psql -d $PG_DB -h $PG_HOST -p $PG_PORT -U $PG_USER -c "CREATE INDEX socrbase_pk_idx ON "$PG_SCHEMA"socrbase USING btree (scname);"
cat "$SCRIPT_DIR"/concat_name.sql | awk '{sub("{{SCHEMA_NAME}}","'$PG_SCHEMA'"); sub("{{USER_NAME}}","'$PG_USER'"); print }' | psql -d $PG_DB -h $PG_HOST -p $PG_PORT -U $PG_USER

echo "Создание партицированных таблиц..."
cat "$SCRIPT_DIR"/tables.sql | awk '{sub("{{SCHEMA_NAME}}","'$PG_SCHEMA'");  sub("{{USER_NAME}}","'$PG_USER'"); print }' | psql -d $PG_DB -h $PG_HOST -p $PG_PORT -U $PG_USER

#****************** ADDROB ******************************
for fn in `find $WORK_DIR -type f -name "ADDROB*"`
do	
	fn_base=`basename "$fn" `
	t_name="${fn_base%.DBF}"
	t_name="${t_name,,}"
	reg_code="${t_name##*addrob}"
	
	#Залить как есть ADDROB*.DBF
	echo "Загрузка файла адресов по региону:"$reg_code""	
	pgdbf -cDp -s cp866 "$fn"  | awk '{sub("CREATE TABLE ","CREATE TABLE IF NOT EXISTS '$PG_SCHEMA'"); sub("DROP TABLE IF EXISTS","DROP TABLE IF EXISTS '$PG_SCHEMA'"); sub("'1000-00-00'","1970-01-01"); sub("COPY ","COPY '$PG_SCHEMA'"); sub("timeout=60000","timeout=999999");  print }' | psql -h $PG_HOST -p $PG_PORT -d $PG_DB -U $PG_USER
	
	echo "Удаление не используемых строк..."
	psql -d $PG_DB -h $PG_HOST -p $PG_PORT -U $PG_USER -c "DELETE FROM "$PG_SCHEMA""$t_name" WHERE livestatus != 1 AND actstatus != 1;"
	
	#Индексы
	echo "Создание индексов..."
	psql -d $PG_DB -h $PG_HOST -p $PG_PORT -U $PG_USER -c "CREATE INDEX "$t_name"_aoguid_idx ON "$PG_SCHEMA""$t_name" USING btree (aoguid);"
	psql -d $PG_DB -h $PG_HOST -p $PG_PORT -U $PG_USER -c "CREATE INDEX "$t_name"_parentguid_idx ON "$PG_SCHEMA""$t_name" USING btree (parentguid);"
	psql -d $PG_DB -h $PG_HOST -p $PG_PORT -U $PG_USER -c "CREATE INDEX "$t_name"_aolevel_idx ON "$PG_SCHEMA""$t_name" USING btree (aolevel);"
	
	echo "Добавление таблицы адресов по региону "$reg_code" в общую таблицу..."
	psql -d $PG_DB -h $PG_HOST -p $PG_PORT -U $PG_USER -c "ALTER TABLE "$PG_SCHEMA"addrobj ATTACH PARTITION "$PG_SCHEMA""$t_name" FOR VALUES IN ('"$reg_code"');"
done

#****************** HOUSE ******************************
for fn in `find $WORK_DIR -type f -name "HOUSE*"`
do	
	fn_base=`basename "$fn" `
	t_name="${fn_base%.DBF}"
	t_name="${t_name,,}"
	reg_code="${t_name##*house}"
	
	echo "Загрузка файла домов по региону:"$reg_code""	
	#Залить как есть HOUSE*.DBF
	pgdbf -cDp -s cp866 "$fn"  | awk '{sub("CREATE TABLE ","CREATE TABLE IF NOT EXISTS '$PG_SCHEMA'"); sub("DROP TABLE IF EXISTS","DROP TABLE IF EXISTS '$PG_SCHEMA'"); sub("'1000-00-00'","1970-01-01"); sub("COPY ","COPY '$PG_SCHEMA'"); sub("timeout=60000","timeout=999999");  print }' | psql -h $PG_HOST -p $PG_PORT -d $PG_DB -U $PG_USER
	
	#Добавить поле для партицирования
	psql -d $PG_DB -h $PG_HOST -p $PG_PORT -U $PG_USER -c "ALTER TABLE "$PG_SCHEMA""$t_name" ADD COLUMN regioncode character varying(2) DEFAULT ('$reg_code');"
	
	echo "Создание индексов..."
	psql -d $PG_DB -h $PG_HOST -p $PG_PORT -U $PG_USER -c "CREATE INDEX "$t_name"_aoguid_pk_idx ON "$PG_SCHEMA""$t_name" USING btree (aoguid);"
	
	echo "Добавление таблицы домов по региону "$reg_code" в общую таблицу..."
	psql -d $PG_DB -h $PG_HOST -p $PG_PORT -U $PG_USER -c "ALTER TABLE "$PG_SCHEMA"house ATTACH PARTITION "$PG_SCHEMA""$t_name" FOR VALUES IN ('"$reg_code"');"
done

#Создать функцию поиска
cat "$SCRIPT_DIR"/aoguid_address.sql | awk '{sub("{{SCHEMA_NAME}}","'$PG_SCHEMA'");  sub("{{USER_NAME}}","'$PG_USER'"); print }' | psql -d $PG_DB -h $PG_HOST -p $PG_PORT -U $PG_USER

echo "Создание материализованного представление для поиска по адресам"
cat "$SCRIPT_DIR"/address_search.sql | awk '{sub("{{SCHEMA_NAME}}","'$PG_SCHEMA'");  sub("{{USER_NAME}}","'$PG_USER'"); print }' | psql -d $PG_DB -h $PG_HOST -p $PG_PORT -U $PG_USER

echo "Создание материализованного представление для поиска до дома"
cat "$SCRIPT_DIR"/house_search.sql | awk '{sub("{{SCHEMA_NAME}}","'$PG_SCHEMA'");  sub("{{USER_NAME}}","'$PG_USER'"); print }' | psql -d $PG_DB -h $PG_HOST -p $PG_PORT -U $PG_USER

#pg_trgm
psql -d $PG_DB -h $PG_HOST -p $PG_PORT -U $PG_USER -c "CREATE EXTENSION IF NOT EXISTS pg_trgm;"

echo "Индексация материализованного представления адресов для поиска like (pg_trgm)"
psql -d $PG_DB -h $PG_HOST -p $PG_PORT -U $PG_USER -c "CREATE INDEX address_search_search_name_idx on "$PG_SCHEMA"address_search USING gin (search_name gin_trgm_ops);"

echo "Индексация материализованного представления ломов для поиска like (pg_trgm)"
psql -d $PG_DB -h $PG_HOST -p $PG_PORT -U $PG_USER -c "CREATE INDEX house_search_search_name_idx on "$PG_SCHEMA"house_search USING gin (search_name gin_trgm_ops);"

#find_address
cat "$SCRIPT_DIR"/find_address.sql | awk '{sub("{{SCHEMA_NAME}}","'$PG_SCHEMA'");  sub("{{USER_NAME}}","'$PG_USER'"); print }' | psql -d $PG_DB -h $PG_HOST -p $PG_PORT -U $PG_USER

