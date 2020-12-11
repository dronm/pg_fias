
DROP MATERIALIZED VIEW IF EXISTS {{SCHEMA_NAME}}address_search;

CREATE MATERIALIZED VIEW {{SCHEMA_NAME}}address_search AS
	SELECT
		sub.aguid_address->>'search_name' AS search_name
		,sub.aguid_address->'addr_struc' AS addr_strucs
		,NULL::json AS house_struc
	FROM
		(SELECT
			{{SCHEMA_NAME}}aoguid_address(ao.aoguid) AS aguid_address
			,ao.regioncode
			,ao.aolevel
		FROM
			{{SCHEMA_NAME}}addrobj ao
		WHERE livestatus=1 and  actstatus=1
		) AS sub
	ORDER BY
		sub.regioncode,sub.aolevel;

