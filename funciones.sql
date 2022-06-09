-- Tablas

CREATE TABLE continente
(
    id INT NOT NULL,
    nombre TEXT NOT NULL,
    PRIMARY KEY(id)
);

CREATE TABLE region
(
    id INT NOT NULL,
    idContinente INT NOT NULL,
    nombre TEXT NOT NULL,
    PRIMARY KEY(id),
    FOREIGN KEY(idContinente) REFERENCES continente ON DELETE CASCADE
);

CREATE TABLE pais
(
    id INT NOT NULL,
    idRegion INT NOT NULL,
    nombre TEXT NOT NULL,
    PRIMARY KEY(id),
    FOREIGN KEY(idRegion) REFERENCES region ON DELETE CASCADE
);

CREATE TABLE anio
(
    anio INT NOT NULL,
    esBisiesto BOOLEAN NOT NULL,
    PRIMARY KEY(anio)
);

CREATE TABLE definitiva
(
    pais INT NOT NULL, -- ID del pais
    total INT NOT NULL,
    aerea INT NOT NULL,
    maritima INT NOT NULL,
    anio INT NOT NULL,
    PRIMARY KEY(pais, anio),
    FOREIGN KEY(anio) REFERENCES anio ON DELETE CASCADE,
    FOREIGN KEY(pais) REFERENCES pais ON DELETE CASCADE
);

-- Eliminar tablas


-- Funciones auxiliares

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

-- Trigger para llenar tablas

DECLARE @global_idContinente INT = 1;
DECLARE @global_idRegion INT = 1;
DECLARE @global_idPais INT = 1;

CREATE OR REPLACE FUNCTION llenarTabla()
RETURNS TRIGGER AS $$
DECLARE
    existeContinente INT;
    existePais INT;
    existeReion INT;
    auxEsBisiesto BOOLEAN;
    existeAnio INT;
BEGIN
    SELECT COUNT(*) INTO existeAnio FROM anio WHERE anio.anio = new.anio;
    IF existeAnio = 0 THEN
        auxEsBisiesto := esBisiesto(new.anio);
        INSERT INTO anio VALUES (new.anio, auxEsBisiesto); 
    END IF;

    SELECT COUNT(*) INTO existeContinente FROM continente WHERE continente.nombre = new.continente;
    IF existeContinente = 0 THEN
        INSERT INTO continente VALUES (@global_idContinente, new.continente);
        @global_idContinente += 1;
    END IF;

    SELECT COUNT(*) INTO existeRegion FROM region WHERE region.nombre = new.region;
    IF existeRegion = 0 THEN
        INSERT INTO region VALUES (@global_idRegion, @global_idContinente, new.region);
        @global_idRegion += 1;
    END IF;

    SELECT COUNT(*) INTO existePais FROM pais WHERE pais.nombre = new.pais;
    IF existePais = 0 THEN
        INSERT INTO pais VALUES (@global_idPais, @global_idRegion, new.pais);
        @global_idPais += 1;
    END IF;

    RETURN new;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER llenarTablaTrigger
BEFORE INSERT OR UPDATE ON definitiva
FOR EACH ROW
EXECUTE PROCEDURE llenarTabla();

/*
-- Trigger de angie

DECLARE @global_idContinente INT = 1;
DECLARE @global_idRegion INT = 1;
DECLARE @global_idPais INT = 1;

CREATE OR REPLACE FUNCTION llenarTabla()
RETURNS TRIGGER AS $$
DECLARE
    existeContinente INT;
    existePais INT;
    existeReion INT;
    auxEsBisiesto BOOLEAN;
    existeAnio INT;
BEGIN
    SELECT COUNT(*) INTO existeAnio FROM anio WHERE anio.anio = new.anio;
    IF existeAnio = 0 THEN
        auxEsBisiesto := esBisiesto(new.anio);
        INSERT INTO anio VALUES (new.anio, auxEsBisiesto); 
    END IF;

    SELECT COUNT(*) INTO existeContinente FROM continente WHERE continente.nombre = new.continente;
    IF existeContinente = 0 THEN
        INSERT INTO continente VALUES (@global_idContinente, new.continente);
        @global_idContinente += 1;
    END IF;

    SELECT COUNT(*) INTO existeRegion FROM region WHERE region.nombre = new.region;
    IF existeRegion = 0 THEN
        INSERT INTO region VALUES (@global_idRegion, @global_idContinente, new.region);
        @global_idRegion += 1;
    END IF;

    SELECT COUNT(*) INTO existePais FROM pais WHERE pais.nombre = new.pais;
    IF existePais = 0 THEN
        INSERT INTO pais VALUES (@global_idPais, @global_idRegion, new.pais);
        @global_idPais += 1;
    END IF;

    RETURN new;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER llenarTablaTrigger
BEFORE INSERT OR UPDATE ON definitiva
FOR EACH ROW
EXECUTE PROCEDURE llenarTabla();

CREATE OR REPLACE FUNCTION llenarId()
RETURNS TRIGGER AS $$
DECLARE
    existeContinente INT;
    existePais INT;
    existeReion INT;
BEGIN

    UPDATE definitiva SET idPais = ...;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER llenarIdTrigger
AFTER INSERT OR UPDATE ON definitiva
EXECUTE PROCEDURE llenarId();

COPY definitiva(
    (SELECT pais.id FROM pais WHERE pais.nombre = new.pais)
    ,Total,Aerea,Maritima,Anio) FROM tourists-rj.csv DELIMITER ',' CSV;
*/

-- Reporte de analisis consolidado

CREATE OR REPLACE FUNCTION AnalisisConsolidado(IN anios INTEGER)
RETURNS VOID AS $$
DECLARE
    anioAnalizado INT;
    imprimirAnio BOOLEAN;
    tipoCategoria CHAR(20);
    categoria CHAR(20);
    total INT;
    totalAnual INT;
    promedio INT;
    promedioAnual INT;
BEGIN
    IF (anios <= 0) THEN
        RAISE WARNING 'La cantidad de anios debe ser mayor a 0.';
        RETURN;
    END IF;

    SELECT min(anio) INTO anioAnalizado FROM anio;

    RAISE NOTICE '-------------------CONSOLIDATED TOURIST REPORT-------------------';
    RAISE NOTICE '-----------------------------------------------------------------';
    RAISE NOTICE 'Year---Category-----------------------------------Total---Average';
    RAISE NOTICE '-----------------------------------------------------------------';

    imprimirAnio := TRUE;

    WHILE (anios>0) LOOP

        /* TODO: esto entra en un loop de fetch
        IF (imprimirAnio = TRUE) THEN
            RAISE NOTICE '%   %: %    %    %', anio, tipoCategoria, categoria, total, promedio;
            imprimirAnio = FALSE;
        ELSE
            RAISE NOTICE '----   %: %    %    %', tipoCategoria, categoria, total, promedio;
        END IF;
        */
        anios := anios - 1;
        anioAnalizado := anioAnalizado + 1;
        imprimirAnio := TRUE;
    END LOOP;

END;
$$ LANGUAGE plpgsql;