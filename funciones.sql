-- Eliminar tablas ---------------------------------------------------------------------------------------------

DROP TABLE IF EXISTS definitiva CASCADE;
DROP TABLE IF EXISTS anio CASCADE;
DROP TABLE IF EXISTS pais CASCADE;
DROP TABLE IF EXISTS region CASCADE;
DROP TABLE IF EXISTS continente CASCADE;
DROP VIEW IF EXISTS auxiliar;

-- Eliminar funciones ------------------------------------------------------------------------------------------

DROP FUNCTION IF EXISTS imprimirEncabezado;
DROP FUNCTION IF EXISTS imprimirData;
DROP FUNCTION IF EXISTS imprimirPie;
DROP FUNCTION IF EXISTS AnalisisConsolidado;

-- Tablas ------------------------------------------------------------------------------------------------------

CREATE TABLE continente
(
    id              INT NOT NULL,
    nombre          TEXT NOT NULL,
    PRIMARY KEY(id),
    UNIQUE(nombre)
);

CREATE TABLE region
(
    id              INT NOT NULL,
    idContinente    INT NOT NULL,
    nombre          TEXT NOT NULL,
    PRIMARY KEY(id),
    FOREIGN KEY(idContinente) REFERENCES continente(id) ON DELETE CASCADE
);

CREATE TABLE pais
(
    id              INT NOT NULL,
    idRegion        INT NOT NULL,
    nombre          TEXT NOT NULL,
    PRIMARY KEY(id),
    FOREIGN KEY(idRegion) REFERENCES region(id) ON DELETE CASCADE
);

CREATE TABLE anio
(
    anio            INT NOT NULL,
    esBisiesto      BOOLEAN NOT NULL,
    PRIMARY KEY(anio)
);

CREATE TABLE definitiva
(
    pais            INT NOT NULL, -- ID del pais
    total           INT NOT NULL CHECK(total >= 0),
    aerea           INT NOT NULL CHECK(aerea >= 0),
    maritima        INT NOT NULL CHECK(maritima >= 0),
    anio            INT NOT NULL,
    PRIMARY KEY(pais, anio),
    FOREIGN KEY(anio) REFERENCES anio ON DELETE CASCADE,
    FOREIGN KEY(pais) REFERENCES pais ON DELETE CASCADE 
);

CREATE VIEW auxiliar AS
SELECT pais.nombre AS pais, total, aerea, maritima, 
        region.nombre AS region, continente.nombre AS continente, anio
FROM definitiva, pais, region, continente
WHERE definitiva.pais = pais.id AND pais.idRegion = region.id AND region.idContinente = continente.id;

-- Funciones auxiliares ----------------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION esBisiesto(panio IN anio.anio%TYPE)
RETURNS anio.esBisiesto%TYPE AS $$
BEGIN
    IF (panio % 4 = 0 AND panio % 100 != 0) THEN
        RETURN TRUE;
    ELSE
        IF (panio % 400 = 0) THEN
            RETURN TRUE;
        END IF;
    END IF;
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- Trigger para llenar tablas ----------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION llenarTabla()
RETURNS TRIGGER AS $$
DECLARE
    existeContinente    INT;
    existePais          INT;
    existeRegion        INT;
    auxEsBisiesto       BOOLEAN;
    existeAnio          INT;
    continenteId        INT;
    regionId            INT;
    paisId              INT;
BEGIN

    -- Si los counts dan 0, es porque el dato no existe en la tabla y debe agregarse

    SELECT COUNT(*) INTO existeAnio FROM anio WHERE anio.anio = new.anio;

    IF existeAnio = 0 THEN
        auxEsBisiesto := esBisiesto(new.anio);
        INSERT INTO anio VALUES (new.anio, auxEsBisiesto); 
    END IF;


    SELECT COUNT(*) INTO existeContinente FROM continente WHERE continente.nombre = new.continente;

    IF existeContinente = 0 THEN
        SELECT COALESCE(MAX(continente.id),0)+1 INTO continenteId FROM continente;
        INSERT INTO continente VALUES (continenteId, new.continente);
    ELSE
        SELECT id INTO continenteId FROM continente WHERE continente.nombre = new.continente;
    END IF;


    SELECT COUNT(*) INTO existeRegion FROM region 
        WHERE region.nombre = new.region AND region.idContinente = continenteId;

    IF existeRegion = 0 THEN
        SELECT COALESCE(MAX(region.id),0)+1 INTO regionId FROM region;
        INSERT INTO region VALUES (regionId, continenteId, new.region);
    ELSE
        SELECT region.id INTO regionId FROM region, continente 
            WHERE region.idContinente = continente.id AND region.nombre = new.region;
    END IF;


    SELECT COUNT(*) INTO existePais FROM pais, region
        WHERE pais.nombre = new.pais AND pais.idRegion = regionId AND region.idContinente = continenteId;

    IF existePais = 0 THEN
        SELECT COALESCE(MAX(pais.id),0)+1 INTO paisId FROM pais;
        INSERT INTO pais VALUES (paisId, regionId, new.pais);
    ELSE
        SELECT pais.id INTO paisId FROM pais, region
            WHERE pais.idRegion = region.id AND region.idContinente = continenteId
                AND pais.nombre = new.pais;
    END IF;


    INSERT INTO definitiva VALUES (paisId, new.total, new.aerea, new.maritima, new.anio);

    RETURN new;
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER llenarTablaTrigger
INSTEAD OF INSERT ON auxiliar
FOR EACH ROW
EXECUTE PROCEDURE llenarTabla();

-- Reporte de analisis consolidado + funciones modularizadas ---------------------------------------------------

CREATE OR REPLACE FUNCTION imprimirEncabezado()
RETURNS VOID AS $$
BEGIN
    RAISE NOTICE '----------------CONSOLIDATED TOURIST REPORT----------------';
    RAISE NOTICE '-----------------------------------------------------------';
    RAISE NOTICE 'Year---Category-----------------------------Total---Average';
    RAISE NOTICE '-----------------------------------------------------------';
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION imprimirData(IN imprimirAnio BOOLEAN, IN anio INT, IN tipoCategoria TEXT,
                                        IN categoria TEXT, IN total INT, IN promedio INT)
RETURNS VOID AS $$
BEGIN
    IF (imprimirAnio = TRUE) THEN
        RAISE NOTICE '%   %: %                    %    %', anio, tipoCategoria, categoria, total, promedio;
    ELSE
        RAISE NOTICE '----   %: %                    %    %', tipoCategoria, categoria, total, promedio;
    END IF;
END;
$$ LANGUAGE plpgsql
RETURNS NULL ON NULL INPUT;


CREATE OR REPLACE FUNCTION imprimirPie(IN total INT, IN promedio INT)
RETURNS VOID AS $$
BEGIN
    RAISE NOTICE '-----------------------------------------   %    %', total, promedio;
    RAISE NOTICE '-----------------------------------------------------------';

END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION AnalisisConsolidado(IN cantAnios INTEGER)
RETURNS VOID AS $$
DECLARE
    cDatosContinente    REFCURSOR;
    rcDatosContinente   RECORD;
    cDatosTransporte    REFCURSOR;
    rcDatosTransporte   RECORD;
    anioAnalizado       INT;
    imprimirAnio        BOOLEAN;
    tipoCategoria       CHAR(20);
    categoria           CHAR(20);
    totalAnual          INT;
    promedioAnual       INT;
BEGIN
    IF (cantAnios <= 0) THEN
        RAISE WARNING 'La cantidad de cantAnios debe ser mayor a 0.';
        RETURN;
    END IF;

    SELECT min(anio.anio) INTO anioAnalizado FROM anio;

    PERFORM imprimirEncabezado();
        
    
    WHILE (cantAnios > 0) LOOP
        imprimirAnio := TRUE;

        OPEN cDatosContinente FOR
            SELECT  continente.id AS idContinente, 
                    continente.nombre AS nombreContinente,
                    COALESCE(SUM(definitiva.total),0) AS total, 
                    COALESCE(AVG(definitiva.total),0) AS promedio
            FROM definitiva JOIN pais ON definitiva.pais = pais.id 
                JOIN region ON pais.idRegion = region.id
                JOIN continente ON region.idContinente = continente.id
            WHERE definitiva.anio = anioAnalizado
            GROUP BY continente.id, anio
            ORDER BY anio, continente.nombre; 
        LOOP
            FETCH cDatosContinente INTO rcDatosContinente;
            EXIT WHEN NOT FOUND;

            tipoCategoria := 'Continente';
            PERFORM imprimirData(imprimirAnio, anioAnalizado, CAST(tipoCategoria AS TEXT), 
                CAST(rcDatosContinente.nombreContinente AS TEXT), 
                CAST(rcDatosContinente.total AS INT), 
                CAST(rcDatosContinente.promedio AS INT));

            imprimirAnio := FALSE;
        END LOOP;
        CLOSE cDatosContinente;


        OPEN cDatosTransporte FOR
            SELECT COALESCE(SUM(definitiva.maritima),0) as maritima, 
                COALESCE(SUM(definitiva.aerea),0) AS aerea, 
                COALESCE(AVG(definitiva.maritima),0) as promMaritima, 
                COALESCE(AVG(definitiva.aerea),0) AS promAerea
            FROM definitiva
            WHERE definitiva.anio = anioAnalizado
            GROUP BY anio
            ORDER BY anio;
            
            FETCH cDatosTransporte INTO rcDatosTransporte;
            EXIT WHEN NOT FOUND;

            tipoCategoria := 'Transporte';
            PERFORM imprimirData(imprimirAnio, anioAnalizado, CAST(tipoCategoria AS TEXT), 
                CAST('Aereo' AS TEXT), 
                CAST(rcDatosTransporte.aerea AS INT), 
                CAST(rcDatosTransporte.promAerea AS INT));
            PERFORM imprimirData(imprimirAnio, anioAnalizado, CAST(tipoCategoria AS TEXT), 
                CAST('Maritimo' AS TEXT), 
                CAST(rcDatosTransporte.maritima AS INT), 
                CAST(rcDatosTransporte.promMaritima AS INT));
        CLOSE cDatosTransporte;


        SELECT COALESCE(SUM(total),0) INTO totalAnual FROM definitiva WHERE definitiva.anio = anioAnalizado;
        SELECT COALESCE(AVG(total),0) INTO promedioAnual FROM definitiva WHERE definitiva.anio = anioAnalizado;
        PERFORM imprimirPie(totalAnual, promedioAnual);

        cantAnios := cantAnios - 1;
        anioAnalizado := anioAnalizado + 1;
    END LOOP;

END;
$$ LANGUAGE plpgsql;