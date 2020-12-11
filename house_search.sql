
DROP MATERIALIZED VIEW IF EXISTS {{SCHEMA_NAME}}house_search;

CREATE MATERIALIZED VIEW {{SCHEMA_NAME}}house_search AS
	SELECT
		sub.aguid_address->>'search_name'||sub.search_house AS search_name
		,sub.aguid_address->'addr_struc' AS addr_strucs
		,sub.house_struc
	FROM
		(SELECT
			{{SCHEMA_NAME}}aoguid_address(ao.aoguid) AS aguid_address
			,ao.regioncode
			,ao.aolevel
			,CASE WHEN coalesce(hs.housenum,'')='' THEN ''
			ELSE ', '||hs.full_name
			END AS search_house				
			
			,json_build_object(
				'aoguid', hs.aoguid
				,'housenum', hs.housenum
				,'buildnum', hs.buildnum
				,'strucnum', hs.strucnum
			) AS house_struc
			,hs.sort AS house_sort
		FROM
			{{SCHEMA_NAME}}addrobj ao
		LEFT JOIN (
			SELECT
				aoguid
				,regioncode
				,housenum
				,buildnum
				,strucnum				
				,CASE WHEN coalesce(housenum,'')='' THEN ''
				ELSE
					'д '||housenum||
					CASE WHEN coalesce(buildnum,'')='' THEN ''
					ELSE ' к '||buildnum
					END
					||
					CASE WHEN coalesce(strucnum,'')='' THEN ''
					ELSE ' стр '||strucnum
					END
				END AS full_name
				,CASE WHEN housenum ~ '^[0-9]+$' THEN housenum::int ELSE 99999 END AS sort
			FROM {{SCHEMA_NAME}}house
			GROUP BY aoguid,regioncode,housenum,buildnum,strucnum
		) AS hs ON hs.aoguid = ao.aoguid
		WHERE livestatus=1 and  actstatus=1
		) AS sub
	ORDER BY
		sub.regioncode
		,sub.house_sort;


