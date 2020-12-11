-- Function: {{SCHEMA_NAME}}concat_name(in_name text,in_sokr_name text)

-- DROP FUNCTION {{SCHEMA_NAME}}concat_name(in_name text,in_sokr_name text)
/**
 * Функция конкатенации наименования по некоторым правилам
 */
CREATE OR REPLACE FUNCTION {{SCHEMA_NAME}}concat_name(in_name text,in_sokr_name text)
  RETURNS text AS  
$$
	WITH
	sokr_inf AS (SELECT level AS lev, socrname FROM {{SCHEMA_NAME}}socrbase WHERE scname=in_sokr_name LIMIT 1)
	SELECT
		CASE
			--Город: сокращение вперед
			WHEN in_sokr_name='г' OR in_sokr_name='г.' THEN 'г '||in_name

			--Улица: сокращение вперед
			WHEN in_sokr_name='ул' OR in_sokr_name='ул.' THEN 'ул '||in_name
			
			--Области вообще не выводим
			WHEN (SELECT lev FROM sokr_inf)=1 OR (SELECT lev FROM sokr_inf)=2 THEN in_name

			--остальное: полное наименование нижний регистр
			ELSE lower((SELECT socrname FROM sokr_inf))||' '||in_name				
		END	
	;
$$
  LANGUAGE sql IMMUTABLE
  COST 100;
ALTER FUNCTION {{SCHEMA_NAME}}concat_name(in_name text,in_sokr_name text) OWNER TO {{USER_NAME}};

