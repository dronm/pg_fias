--партиционная таблица всех адресов
CREATE TABLE IF NOT EXISTS {{SCHEMA_NAME}}addrobj
(
    actstatus numeric(2,0),
    aoguid character varying(36),
    aoid character varying(36),
    aolevel numeric(2,0),
    areacode character varying(3),
    autocode character varying(1),
    centstatus numeric(2,0),
    citycode character varying(3),
    code character varying(17),
    currstatus numeric(2,0),
    enddate date,
    formalname character varying(120),
    ifnsfl character varying(4),
    ifnsul character varying(4),
    nextid character varying(36),
    offname character varying(120),
    okato character varying(11),
    oktmo character varying(11),
    operstatus numeric(2,0),
    parentguid character varying(36),
    placecode character varying(3),
    plaincode character varying(15),
    postalcode character varying(6),
    previd character varying(36),
    regioncode character varying(2),
    shortname character varying(10),
    startdate date,
    streetcode character varying(4),
    terrifnsfl character varying(4),
    terrifnsul character varying(4),
    updatedate date,
    ctarcode character varying(3),
    extrcode character varying(4),
    sextcode character varying(3),
    livestatus numeric(2,0),
    normdoc character varying(36),
    plancode character varying(4),
    cadnum character varying(100),
    divtype numeric(1,0)
)
PARTITION BY LIST (regioncode)
WITH (
    OIDS = FALSE
);
ALTER TABLE {{SCHEMA_NAME}}addrobj OWNER TO {{USER_NAME}};

--партиционная таблица всех домов
CREATE TABLE IF NOT EXISTS {{SCHEMA_NAME}}house
(
    aoguid character varying(36),
    buildnum character varying(50),
    enddate date,
    eststatus numeric(2,0),
    houseguid character varying(36),
    houseid character varying(36),
    housenum character varying(20),
    statstatus numeric(5,0),
    ifnsfl character varying(4),
    ifnsul character varying(4),
    okato character varying(11),
    oktmo character varying(11),
    postalcode character varying(6),
    startdate date,
    strucnum character varying(50),
    strstatus numeric(1,0),
    terrifnsfl character varying(4),
    terrifnsul character varying(4),
    updatedate date,
    normdoc character varying(36),
    counter numeric(4,0),
    cadnum character varying(100),
    divtype numeric(2,0),
    regioncode character varying(2)
) PARTITION BY LIST (regioncode)
WITH (
    OIDS = FALSE
)
TABLESPACE pg_default;
ALTER TABLE {{SCHEMA_NAME}}house OWNER TO {{USER_NAME}};
