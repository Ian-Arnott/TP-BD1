-- Tablas ------------------------------------------------------------------------------------------------------

CREATE TABLE continente
(
    id              INT NOT NULL,
    nombre          TEXT NOT NULL,
    PRIMARY KEY(id)
);

CREATE TABLE region
(
    id              INT NOT NULL,
    idContinente    INT NOT NULL,
    nombre          TEXT NOT NULL,
    PRIMARY KEY(id),
    FOREIGN KEY(idContinente) REFERENCES continente ON DELETE CASCADE -- TODO Necesita...? ON UPDATE RESTRICT
);

CREATE TABLE pais
(
    id              INT NOT NULL,
    idRegion        INT NOT NULL,
    nombre          TEXT NOT NULL,
    PRIMARY KEY(id),
    FOREIGN KEY(idRegion) REFERENCES region ON DELETE CASCADE -- TODO Necesita...? ON UPDATE RESTRICT
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
    FOREIGN KEY(anio) REFERENCES anio ON DELETE CASCADE, -- TODO Necesita...? ON UPDATE RESTRICT
    FOREIGN KEY(pais) REFERENCES pais ON DELETE CASCADE -- TODO Necesita...? ON UPDATE RESTRICT
);

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
    idContinente        INT;
    idRegion            INT;
    idPais              INT;
BEGIN

    -- Si los counts dan 0, es porque el dato no existe en la tabla y debe agregarse

    SELECT COUNT(*) INTO existeAnio FROM anio WHERE anio.anio = new.anio;
    IF existeAnio = 0 THEN
        auxEsBisiesto := esBisiesto(new.anio);
        INSERT INTO anio VALUES (new.anio, auxEsBisiesto); 
    END IF;

    SELECT COUNT(*) INTO existeContinente FROM continente WHERE continente.nombre = new.continente;
    IF existeContinente = 0 THEN
        SELECT COALESCE(MAX(continente.id),0)+1 INTO idContinente FROM continente;
        INSERT INTO continente VALUES (idContinente, new.continente);
    END IF;

    SELECT COUNT(*) INTO existeRegion FROM region WHERE region.nombre = new.region;
    IF existeRegion = 0 THEN
        SELECT COALESCE(MAX(region.id),0)+1 INTO idRegion FROM region;
        SELECT continente.id INTO idContinente FROM continente WHERE continente.nombre = new.continente;
        INSERT INTO region VALUES (idRegion, idContinente, new.region);
    END IF;

    SELECT COUNT(*) INTO existePais FROM pais WHERE pais.nombre = new.pais;
    IF existePais = 0 THEN
        SELECT COALESCE(MAX(pais.id),0)+1 INTO idPais FROM pais;
        SELECT region.id INTO idRegion FROM region WHERE region.nombre = new.region;
        INSERT INTO pais VALUES (idPais, idRegion, new.pais);
    END IF;

    RETURN new;
END;
$$ LANGUAGE plpgsql;

-- TODO a chequear este trigger
CREATE TRIGGER llenarTablaTrigger
BEFORE INSERT OR UPDATE ON definitiva
FOR EACH ROW
EXECUTE PROCEDURE llenarTabla();

-- Reporte de analisis consolidado + funciones modularizadas ---------------------------------------------------

CREATE OR REPLACE FUNCTION imprimirEncabezado()
RETURNS VOID AS $$
BEGIN
    RAISE NOTICE '-------------------CONSOLIDATED TOURIST REPORT-------------------';
    RAISE NOTICE '-----------------------------------------------------------------';
    RAISE NOTICE 'Year---Category-----------------------------------Total---Average';
    RAISE NOTICE '-----------------------------------------------------------------';
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION imprimirData(IN imprimirAnio BOOLEAN, IN anio INT, IN tipoCategoria TEXT,
                                        IN categoria TEXT, IN total INT, IN promedio INT)
RETURNS VOID AS $$
BEGIN
    IF (imprimirAnio = TRUE) THEN
        RAISE NOTICE '%   %: %    %    %', anio, tipoCategoria, categoria, total, promedio;
    ELSE
        RAISE NOTICE '----   %: %    %    %', tipoCategoria, categoria, total, promedio;
    END IF;
END;
$$ LANGUAGE plpgsql
RETURNS NULL ON NULL INPUT;


CREATE OR REPLACE FUNCTION imprimirPie(IN total INT, IN promedio INT)
RETURNS VOID AS $$
BEGIN
    RAISE NOTICE '--------------------------------------   %    %', total, promedio;
    RAISE NOTICE '-----------------------------------------------------------------';

END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION AnalisisConsolidado(IN anios INTEGER)
RETURNS VOID AS $$
DECLARE
    anioAnalizado       INT;
    imprimirAnio        BOOLEAN;
    tipoCategoria       CHAR(20);
    categoria           CHAR(20);
    total               INT;
    totalAnual          INT;
    promedio            INT;
    promedioAnual       INT;
BEGIN
    IF (anios <= 0) THEN
        RAISE WARNING 'La cantidad de anios debe ser mayor a 0.';
        RETURN;
    END IF;

    SELECT min(anio) INTO anioAnalizado FROM anio;

    PERFORM imprimirEncabezado();

    WHILE (anios > 0) LOOP
        imprimirAnio := TRUE;


        /* Adentro del fetch
        PERFORM imprimirData(imprimirAnio, anio, tipoCategoria,categoria, total, promedio);
        */
        SELECT COALESCE(SUM(total),0) INTO totalAnual FROM definitiva WHERE definitiva.anio = anioAnalizado;
        SELECT COALESCE(AVG(total),0) INTO promedioAnual FROM definitiva WHERE definitiva.anio = anioAnalizado;
        PERFORM imprimirPie(totalAnual, promedioAnual);

        anios := anios - 1;
        anioAnalizado := anioAnalizado + 1;
    END LOOP;

END;
$$ LANGUAGE plpgsql;

-- Eliminar tablas ---------------------------------------------------------------------------------------------

DROP TABLE IF EXISTS definitiva;
DROP TABLE IF EXISTS anio;
DROP TABLE IF EXISTS pais;
DROP TABLE IF EXISTS region;
DROP TABLE IF EXISTS continente;

-- Eliminar funciones ------------------------------------------------------------------------------------------

DROP FUNCTION IF EXISTS imprimirEncabezado;
DROP FUNCTION IF EXISTS imprimirData;
DROP FUNCTION IF EXISTS imprimirPie;
DROP FUNCTION IF EXISTS AnalisisConsolidado;