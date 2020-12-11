-- Function: {{SCHEMA_NAME}}aoguid_address(in_aguid text)

-- DROP FUNCTION {{SCHEMA_NAME}}aoguid_address(in_aguid text);
-- 'f1127b16-8a8e-4520-b1eb-6932654abdcd' test guid

CREATE OR REPLACE FUNCTION {{SCHEMA_NAME}}aoguid_address(in_aguid text)
  RETURNS JSON AS  
$$
	WITH RECURSIVE
		child_to_parents AS (
			SELECT
				addrobj.*
			FROM {{SCHEMA_NAME}}addrobj
			WHERE
				aoguid = in_aguid
				AND addrobj.livestatus=1 and  addrobj.actstatus=1
			UNION ALL
			SELECT
				addrobj.*
			FROM {{SCHEMA_NAME}}addrobj, child_to_parents
			WHERE addrobj.aoguid = child_to_parents.parentguid
			AND addrobj.livestatus=1 and  addrobj.actstatus=1
		)
		SELECT
			json_build_object(
				'search_name', string_agg( fias.concat_name(expanded.offname,expanded.shortname),', ')
				,'addr_struc', array_agg(expanded.addr)
			)
		FROM (
			SELECT
				offname
				,shortname
				,json_build_object(
					'aolevel', aolevel
					,'aoguid', aoguid
					,'shortname', shortname
					,'offname', offname
					,'regioncode', regioncode
				) AS addr
			FROM child_to_parents
			ORDER BY aolevel
		) AS expanded	
	;
$$
  LANGUAGE sql VOLATILE
  COST 100;

