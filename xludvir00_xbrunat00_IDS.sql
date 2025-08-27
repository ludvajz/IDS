--------------------------------------------------------------------------
-- DROP starých tabulek a sekvence
--------------------------------------------------------------------------
DROP TABLE vysetreni       CASCADE CONSTRAINTS;
DROP TABLE pacient_lek     CASCADE CONSTRAINTS;
DROP TABLE recept_lek      CASCADE CONSTRAINTS;
DROP TABLE lek             CASCADE CONSTRAINTS;
DROP TABLE recept          CASCADE CONSTRAINTS;
DROP TABLE pacient         CASCADE CONSTRAINTS;
DROP TABLE lekar           CASCADE CONSTRAINTS;
DROP TABLE oddeleni        CASCADE CONSTRAINTS;
DROP TABLE osoba           CASCADE CONSTRAINTS;
DROP TABLE audit_log_pacient CASCADE CONSTRAINTS PURGE;

DROP MATERIALIZED VIEW mv_pocet_pacientu_na_oddeleni;


DROP SEQUENCE seq_osoba;

--------------------------------------------------------------------------
-- Vytvoření sekvence pro primární klíč v tabulce OSOBA
--------------------------------------------------------------------------
CREATE SEQUENCE seq_osoba START WITH 1 INCREMENT BY 1;

--------------------------------------------------------------------------
-- TABULKA OSOBA (generalizace)
-- 1. tabulka pro nadtyp + pro podtypy s primárním klíčem nadtypu
--------------------------------------------------------------------------
CREATE TABLE osoba (
    id_osoby        NUMBER
        DEFAULT seq_osoba.NEXTVAL
        NOT NULL,
    jmeno           VARCHAR2(50)  NOT NULL,
    prijmeni        VARCHAR2(50)  NOT NULL,
    rodne_cislo     VARCHAR2(11)  NOT NULL UNIQUE,
    datum_narozeni  DATE          NOT NULL,
    mesto           VARCHAR2(100),
    ulice           VARCHAR2(100),
    psc             VARCHAR2(6),
    telefon         VARCHAR2(30),

    CONSTRAINT pk_osoba PRIMARY KEY (id_osoby),
    CONSTRAINT ck_osoba_rodne_cislo CHECK (
        REGEXP_LIKE(rodne_cislo, '^[0-9]{6}/?[0-9]{3,4}$')
    ),
    CONSTRAINT ck_osoba_psc CHECK (
        psc IS NULL
        OR REGEXP_LIKE(psc, '^[0-9]{3}\s?[0-9]{2}$')
    )
);

--------------------------------------------------------------------------
-- TABULKA LÉKAŘ (specializace) - bez vazby na oddělení (přidáme později)
--------------------------------------------------------------------------
CREATE TABLE lekar (
    id_osoby      NUMBER       NOT NULL,
    login         VARCHAR2(50)  NOT NULL UNIQUE,
    hash          VARCHAR2(200) NOT NULL,
    datum_nastupu DATE          NOT NULL,
    email         VARCHAR2(100) UNIQUE,
    specializace  VARCHAR2(100),
    cislo_licence VARCHAR2(30)  NOT NULL UNIQUE,
    id_oddeleni   NUMBER,

    CONSTRAINT pk_lekar PRIMARY KEY (id_osoby),
    CONSTRAINT fk_lekar_osoba
        FOREIGN KEY (id_osoby) REFERENCES osoba (id_osoby)
        ON DELETE CASCADE
);

--------------------------------------------------------------------------
-- TABULKA ODDĚLENÍ - s FK na vedoucího lékaře
--------------------------------------------------------------------------
CREATE TABLE oddeleni (
    id_oddeleni NUMBER GENERATED ALWAYS AS IDENTITY NOT NULL,
    nazev       VARCHAR2(100) NOT NULL UNIQUE,
    umisteni    VARCHAR2(100),
    id_vedouci  NUMBER UNIQUE NOT NULL,

    CONSTRAINT pk_oddeleni PRIMARY KEY (id_oddeleni)
);

--------------------------------------------------------------------------
-- TABULKA PACIENT (specializace tabulky OSOBA)
--------------------------------------------------------------------------
CREATE TABLE pacient (
    id_osoby          NUMBER      NOT NULL,
    cislo_pojistovny NUMBER      NOT NULL,
    cislo_pojistence NUMBER      NOT NULL,
    datum_registrace DATE        NOT NULL,

    CONSTRAINT pk_pacient PRIMARY KEY (id_osoby),
    CONSTRAINT fk_pacient_osoba
        FOREIGN KEY (id_osoby) REFERENCES osoba (id_osoby)
        ON DELETE CASCADE,
    CONSTRAINT uk_pacient_pojistence UNIQUE (cislo_pojistovny, cislo_pojistence),
    CONSTRAINT ck_pacient_pojistence CHECK (
        REGEXP_LIKE(cislo_pojistence, '^[0-9]{9,10}$')
    )
);

--------------------------------------------------------------------------
-- TABULKA RECEPT
--------------------------------------------------------------------------
CREATE TABLE recept (
    id_receptu      NUMBER GENERATED ALWAYS AS IDENTITY NOT NULL,
    datum_vystaveni DATE NOT NULL,
    datum_platnosti DATE,
    poznamka        VARCHAR2(400),
    id_pacient      NUMBER NOT NULL,
    id_lekar        NUMBER,

    CONSTRAINT pk_recept PRIMARY KEY (id_receptu),
    CONSTRAINT fk_recept_pacient
        FOREIGN KEY (id_pacient) REFERENCES pacient (id_osoby)
        ON DELETE CASCADE,
    CONSTRAINT fk_recept_lekar
        FOREIGN KEY (id_lekar) REFERENCES lekar (id_osoby)
        ON DELETE SET NULL,
    CONSTRAINT ck_recept_platnost CHECK (datum_platnosti IS NULL OR datum_platnosti >= datum_vystaveni)
);

--------------------------------------------------------------------------
-- TABULKA LÉK
--------------------------------------------------------------------------
CREATE TABLE lek (
    id_leku NUMBER GENERATED ALWAYS AS IDENTITY NOT NULL,
    nazev   VARCHAR2(100) NOT NULL UNIQUE,

    CONSTRAINT pk_lek PRIMARY KEY (id_leku)
);

--------------------------------------------------------------------------
-- TABULKA RECEPT_LEK (M:N vztah Recept – Lék)
--------------------------------------------------------------------------
CREATE TABLE recept_lek (
    id         NUMBER GENERATED ALWAYS AS IDENTITY NOT NULL,
    id_receptu NUMBER NOT NULL,
    id_leku    NUMBER NOT NULL,
    davkovani  VARCHAR2(100),
    mnozstvi   NUMBER,

    CONSTRAINT pk_recept_lek PRIMARY KEY (id),
    CONSTRAINT fk_recept_lek_recept
        FOREIGN KEY (id_receptu) REFERENCES recept (id_receptu)
        ON DELETE CASCADE,
    CONSTRAINT fk_recept_lek_lek
        FOREIGN KEY (id_leku) REFERENCES lek (id_leku),
    CONSTRAINT uk_recept_lek UNIQUE (id_receptu, id_leku)
);

--------------------------------------------------------------------------
-- TABULKA PACIENT_LEK (M:N mezi Pacient a Lék)
--------------------------------------------------------------------------
CREATE TABLE pacient_lek (
    id       NUMBER GENERATED ALWAYS AS IDENTITY NOT NULL,
    id_osoby NUMBER NOT NULL,
    id_leku  NUMBER NOT NULL,

    CONSTRAINT pk_pacient_lek PRIMARY KEY (id),
    CONSTRAINT fk_pl_pacient
        FOREIGN KEY (id_osoby) REFERENCES pacient (id_osoby)
        ON DELETE CASCADE,
    CONSTRAINT fk_pl_lek
        FOREIGN KEY (id_leku) REFERENCES lek (id_leku)
);

--------------------------------------------------------------------------
-- TABULKA VYŠETŘENÍ
--------------------------------------------------------------------------
CREATE TABLE vysetreni (
    id_vysetreni NUMBER GENERATED ALWAYS AS IDENTITY NOT NULL,
    datum        DATE NOT NULL,
    zprava       VARCHAR2(1000),
    id_pacient   NUMBER NOT NULL,
    id_lekar     NUMBER,

    CONSTRAINT pk_vysetreni PRIMARY KEY (id_vysetreni),
    CONSTRAINT fk_vysetreni_pacient
        FOREIGN KEY (id_pacient) REFERENCES pacient (id_osoby)
        ON DELETE CASCADE,
    CONSTRAINT fk_vysetreni_lekar
        FOREIGN KEY (id_lekar) REFERENCES lekar (id_osoby)
        ON DELETE SET NULL
);

--------------------------------------------------------------------------
-- Tabulka pro evidenci (logování) změn u pacienta
--------------------------------------------------------------------------
CREATE TABLE audit_log_pacient (
    id_log        NUMBER GENERATED ALWAYS AS IDENTITY NOT NULL PRIMARY KEY,
    id_pacient    NUMBER NOT NULL,
    sloupec       VARCHAR2(30) NOT NULL,
    stara_hodnota VARCHAR2(50),
    nova_hodnota  VARCHAR2(50),
    zmenil_uzivatel VARCHAR2(100) DEFAULT USER,
    cas_zmeny     TIMESTAMP DEFAULT SYSTIMESTAMP,
    CONSTRAINT fk_audit_pacient FOREIGN KEY (id_pacient) REFERENCES pacient(id_osoby) ON DELETE CASCADE
);



--------------------------------------------------------------------------
-- Přidání vazby pro Lékaře na oddělení
--------------------------------------------------------------------------
ALTER TABLE lekar
    ADD CONSTRAINT fk_lekar_oddeleni
        FOREIGN KEY (id_oddeleni) REFERENCES oddeleni (id_oddeleni)
        ON DELETE SET NULL;

--------------------------------------------------------------------------
-- Přidání vazby pro vedoucího na oddělení
--------------------------------------------------------------------------
ALTER TABLE oddeleni
    ADD CONSTRAINT fk_oddeleni_vedouci
        FOREIGN KEY (id_vedouci) REFERENCES lekar (id_osoby);

--------------------------------------------------------------------------
-- EXAMPLE DATA
--------------------------------------------------------------------------


INSERT INTO osoba (id_osoby, jmeno, prijmeni, rodne_cislo, datum_narozeni,
                   mesto, ulice, psc, telefon)
VALUES (101, 'Jan', 'Novák', '750101/1234', DATE '1975-01-01',
        'Praha', 'Bělehradská 22', '12000', '+420 723 111 222');

INSERT INTO osoba (id_osoby, jmeno, prijmeni, rodne_cislo, datum_narozeni,
                   mesto, ulice, psc, telefon)
VALUES (82, 'Petr', 'Svoboda', '680215/5678', DATE '1968-02-15',
        'Brno', 'Veveří 95', '60200', '+420 606 333 444');

INSERT INTO osoba (id_osoby, jmeno, prijmeni, rodne_cislo, datum_narozeni,
                   mesto, ulice, psc, telefon)
VALUES (37, 'Alena', 'Dvořáková', '920530/111', DATE '1992-05-30',
        'Ostrava', 'Nádražní 120', '70200', '+420 731 555 777');

INSERT INTO osoba (id_osoby, jmeno, prijmeni, rodne_cislo, datum_narozeni,
                   mesto, ulice, psc, telefon)
VALUES (56, 'Michaela', 'Horáková', '865010/888', DATE '1986-05-10',
        'Plzeň', 'Klatovská 12', '30100', '+420 777 222 111');


INSERT INTO osoba (id_osoby, jmeno, prijmeni, rodne_cislo, datum_narozeni,
                   mesto, ulice, psc, telefon)
VALUES (211, 'Lucie', 'Králová', '025010/999', DATE '2002-05-10',
        'Hradec Králové', 'Gočárova 10', '50002', '+420 608 111 999');

INSERT INTO osoba (id_osoby, jmeno, prijmeni, rodne_cislo, datum_narozeni,
                   mesto, ulice, psc, telefon)
VALUES (104, 'Tomáš', 'Procházka', '991201/2345', DATE '1999-12-01',
        'Olomouc', 'Foerstrova 88', '77900', '+420 702 666 555');

INSERT INTO osoba (id_osoby, jmeno, prijmeni, rodne_cislo, datum_narozeni,
                   mesto, ulice, psc, telefon)
VALUES (75, 'Barbora', 'Veselá', '755120/444', DATE '1975-12-20',
        'Zlín', 'Tř. Tomáše Bati 53', '76001', '+420 728 345 111');

INSERT INTO osoba (id_osoby, jmeno, prijmeni, rodne_cislo, datum_narozeni,
                   mesto, ulice, psc, telefon)
VALUES (99, 'Aleš', 'Zeman', '930610/777', DATE '1993-06-10',
        'České Budějovice', 'Rudolfovská 14', '37001', '+420 777 456 123');
        

INSERT INTO osoba (id_osoby, jmeno, prijmeni, rodne_cislo, datum_narozeni, mesto, ulice, psc, telefon)
VALUES (300, 'Martin', 'Novotný', '050505/5555', DATE '2005-05-05', 'Liberec', 'Husova 5', '46001', '+420 777 888 999');

INSERT INTO lekar (id_osoby, login, hash, datum_nastupu, email, specializace,
                   cislo_licence, id_oddeleni)
VALUES (101, 'janN', 'hash1', DATE '2005-03-01', 'jan.novak@nemocnice.cz',
        'Chirurg', 'CZ-CH111', NULL);

INSERT INTO lekar (id_osoby, login, hash, datum_nastupu, email, specializace,
                   cislo_licence, id_oddeleni)
VALUES (82, 'petrS', 'hash2', DATE '2000-10-12', 'petr.svoboda@nemocnice.cz',
        'Internista', 'CZ-IN222', NULL);

INSERT INTO lekar (id_osoby, login, hash, datum_nastupu, email, specializace,
                   cislo_licence, id_oddeleni)
VALUES (37, 'alenaD', 'hash3', DATE '2015-01-20', 'alena.dvorakova@nemocnice.cz',
        'Ortoped', 'CZ-OR333', NULL);

INSERT INTO lekar (id_osoby, login, hash, datum_nastupu, email, specializace,
                   cislo_licence, id_oddeleni)
VALUES (56, 'misaH', 'hash4', DATE '2012-06-15', 'm.horakova@nemocnice.cz',
        'Kardiolog', 'CZ-KA444', NULL);


INSERT INTO oddeleni (nazev, umisteni, id_vedouci)
VALUES ('Chirurgie', 'Pavilon A', 101);

INSERT INTO oddeleni (nazev, umisteni, id_vedouci)
VALUES ('Interna', 'Pavilon B', 82);

INSERT INTO oddeleni (nazev, umisteni, id_vedouci)
VALUES ('Ortopedie', 'Pavilon C', 37);

INSERT INTO oddeleni (nazev, umisteni, id_vedouci)
VALUES ('Kardiologie', 'Pavilon D', 56);

UPDATE lekar SET id_oddeleni = 1 WHERE id_osoby = 101;  -- Jan => Chirurgie
UPDATE lekar SET id_oddeleni = 2 WHERE id_osoby = 82;   -- Petr => Interna
UPDATE lekar SET id_oddeleni = 3 WHERE id_osoby = 37;   -- Alena => Ortopedie
UPDATE lekar SET id_oddeleni = 4 WHERE id_osoby = 56;   -- Míša => Kardiologie


INSERT INTO pacient (id_osoby, cislo_pojistovny, cislo_pojistence, datum_registrace)
VALUES (211, 111, 123456789, SYSDATE - 7);

INSERT INTO pacient (id_osoby, cislo_pojistovny, cislo_pojistence, datum_registrace)
VALUES (104, 205, 987654321, SYSDATE - 10);

INSERT INTO pacient (id_osoby, cislo_pojistovny, cislo_pojistence, datum_registrace)
VALUES (75, 213, 998877665, SYSDATE - 2);

INSERT INTO pacient (id_osoby, cislo_pojistovny, cislo_pojistence, datum_registrace)
VALUES (99, 333, 777555111, SYSDATE - 12);

INSERT INTO pacient (id_osoby, cislo_pojistovny, cislo_pojistence, datum_registrace)
VALUES (300, 444, 112233445, SYSDATE - 1);


INSERT INTO recept (datum_vystaveni, datum_platnosti, poznamka, id_pacient, id_lekar)
VALUES (SYSDATE, SYSDATE + 14, 'Pooperační analgetika', 211, 101);

INSERT INTO recept (datum_vystaveni, datum_platnosti, poznamka, id_pacient, id_lekar)
VALUES (SYSDATE - 3, SYSDATE + 5, 'Na zánět', 104, 82);

INSERT INTO recept (datum_vystaveni, datum_platnosti, poznamka, id_pacient, id_lekar)
VALUES (SYSDATE - 1, SYSDATE + 10, 'Bolest kloubů', 75, 37);

INSERT INTO recept (datum_vystaveni, datum_platnosti, poznamka, id_pacient, id_lekar)
VALUES (SYSDATE - 2, SYSDATE + 20, 'Na srdeční obtíže', 99, 56);


INSERT INTO lek (nazev) VALUES ('Brufen 400mg');
INSERT INTO lek (nazev) VALUES ('Ibalgin 200mg');
INSERT INTO lek (nazev) VALUES ('Paralen 500mg');
INSERT INTO lek (nazev) VALUES ('Penicilin 1MU');


INSERT INTO recept_lek (id_receptu, id_leku, davkovani, mnozstvi)
VALUES (1, 1, '1 tableta 3x denně', 15);

INSERT INTO recept_lek (id_receptu, id_leku, davkovani, mnozstvi)
VALUES (2, 2, '2 tablety 2x denně', 10);

INSERT INTO recept_lek (id_receptu, id_leku, davkovani, mnozstvi)
VALUES (3, 3, '1 tableta 1x denně', 20);

INSERT INTO recept_lek (id_receptu, id_leku, davkovani, mnozstvi)
VALUES (4, 4, '1 tableta 4x denně', 25);


INSERT INTO pacient_lek (id_osoby, id_leku)
VALUES (211, 1);

INSERT INTO pacient_lek (id_osoby, id_leku)
VALUES (104, 2);

INSERT INTO pacient_lek (id_osoby, id_leku)
VALUES (75, 3);

INSERT INTO pacient_lek (id_osoby, id_leku)
VALUES (99, 4);


INSERT INTO vysetreni (datum, zprava, id_pacient, id_lekar)
VALUES (SYSDATE - 4, 'Kontrola stehu po operaci', 211, 101);

INSERT INTO vysetreni (datum, zprava, id_pacient, id_lekar)
VALUES (SYSDATE - 1, 'Interní vyšetření dutiny břišní', 104, 82);

INSERT INTO vysetreni (datum, zprava, id_pacient, id_lekar)
VALUES (SYSDATE - 2, 'Ortopedická kontrola kolene', 75, 37);

INSERT INTO vysetreni (datum, zprava, id_pacient, id_lekar)
VALUES (SYSDATE - 3, 'Kardiologický test EKG', 99, 56);

INSERT INTO vysetreni (datum, zprava, id_pacient, id_lekar)
VALUES (SYSDATE - 30, 'Dřívější kontrola 1 - kyčel', 75, 37);

INSERT INTO vysetreni (datum, zprava, id_pacient, id_lekar)
VALUES (SYSDATE - 60, 'Dřívější kontrola 2 - kyčel', 75, 37);

INSERT INTO vysetreni (datum, zprava, id_pacient, id_lekar)
VALUES (SYSDATE - 90, 'Dřívější kontrola 3 - kyčel', 75, 37);

COMMIT;

--------------------------------------------------------------------------
-- SELECTS
--------------------------------------------------------------------------
-- Dotaz 1: Vyhledá seznam pacientů s jejich osobními údaji.
SELECT o.id_osoby, o.jmeno, o.prijmeni, 
       p.cislo_pojistovny, p.cislo_pojistence, p.datum_registrace
FROM pacient p
JOIN osoba o ON p.id_osoby = o.id_osoby;

-- Dotaz 2: Vyhledá seznam lékařů s jejich osobními údaji.
SELECT o.id_osoby, o.jmeno, o.prijmeni, 
       l.login, l.specializace, l.datum_nastupu
FROM lekar l
JOIN osoba o ON l.id_osoby = o.id_osoby;

-- Dotaz 3: Vyhledá detaily o lécích předepisovaných v receptu, včetně dávkování a množství.
SELECT r.id_receptu, l.nazev AS nazev_leku, 
       rl.davkovani, rl.mnozstvi
FROM recept r
JOIN recept_lek rl ON r.id_receptu = rl.id_receptu
JOIN lek l ON rl.id_leku = l.id_leku;

-- Dotaz 4: Vyhledá počet předepsaných receptů pro každého lékaře.
SELECT r.id_lekar, COUNT(*) AS pocet_receptu
FROM recept r
GROUP BY r.id_lekar;

-- Dotaz 5: Vyhledá počet provedených vyšetření pro každého pacienta.
SELECT v.id_pacient, COUNT(*) AS pocet_vysetreni
FROM vysetreni v
GROUP BY v.id_pacient;

-- Dotaz 6: Vyhledá lékaře, kteří vystavili alespoň jeden recept.
SELECT l.id_osoby, l.login, l.specializace
FROM lekar l
WHERE EXISTS (
    SELECT 1 
    FROM recept r
    WHERE r.id_lekar = l.id_osoby
);

-- Dotaz 7: Vyhledá pacienty, kteří mají vystaven recept (jejich ID se nachází v tabulce recept).
SELECT o.id_osoby, o.jmeno, o.prijmeni
FROM osoba o
WHERE o.id_osoby IN (
    SELECT r.id_pacient
    FROM recept r
);

COMMIT;
--------------------------------------------------------------------------
-- Triggery
--------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_audit_zmena_pojisteni
AFTER UPDATE OF cislo_pojistovny, cislo_pojistence ON pacient
FOR EACH ROW
WHEN (NEW.cislo_pojistovny != OLD.cislo_pojistovny OR
      NEW.cislo_pojistence != OLD.cislo_pojistence )
DECLARE
    v_sloupec VARCHAR(30);
BEGIN

    IF UPDATING('cislo_pojistovny') AND :NEW.cislo_pojistovny != :OLD.cislo_pojistovny THEN
        v_sloupec := 'cislo_pojistovny';
        INSERT INTO audit_log_pacient (id_pacient, sloupec, stara_hodnota, nova_hodnota)
        VALUES (:OLD.id_osoby, v_sloupec, TO_CHAR(:OLD.cislo_pojistovny), TO_CHAR(:NEW.cislo_pojistovny));
    END IF;


    IF UPDATING('cislo_pojistence') AND :NEW.cislo_pojistence != :OLD.cislo_pojistence THEN
         v_sloupec := 'cislo_pojistence';
         INSERT INTO audit_log_pacient (id_pacient, sloupec, stara_hodnota, nova_hodnota)
         VALUES (:OLD.id_osoby, v_sloupec, TO_CHAR(:OLD.cislo_pojistence), TO_CHAR(:NEW.cislo_pojistence));
    END IF;
END;
/


CREATE OR REPLACE TRIGGER trg_kontrola_odstraneni_vedouciho
BEFORE DELETE ON lekar
FOR EACH ROW
DECLARE
    v_pocet NUMBER;
BEGIN
    SELECT COUNT(*)
    INTO v_pocet
    FROM oddeleni
    WHERE id_vedouci = :OLD.id_osoby;

     IF v_pocet > 0 THEN
         RAISE_APPLICATION_ERROR(-20001, 'Nelze smazat lékaře (' || :OLD.id_osoby || ' - ' || :OLD.login || '), který je vedoucím oddělení. Nejprve změňte vedoucího daného oddělení.');
    END IF;
END;
/

--------------------------------------------------------------------------
-- Předvedení triggerů
-------------------------------------------------------------------------
PROMPT Test triggeru 1: Audit změn pojištění pacienta
UPDATE pacient 
SET cislo_pojistovny = 999, cislo_pojistence = 1112223330 -- Změna údajů
WHERE id_osoby = 211;
COMMIT;

PROMPT Ověření, že se vytvořily záznamy v logu (měly by být 2)
SELECT id_log, sloupec, stara_hodnota, nova_hodnota FROM audit_log_pacient WHERE id_pacient = 211 ORDER BY id_log DESC FETCH FIRST 2 ROWS ONLY;
COMMIT;

PROMPT Test triggeru 2: Zákaz smazání vedoucího (chyba ORA-20001)
DELETE FROM lekar WHERE id_osoby = 101;

--------------------------------------------------------------------------
-- PROCEDURY
--------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE najdi_vysetreni_pacienta (p_id_pacient IN pacient.id_osoby%TYPE) 
AS 
v_jmeno_pacienta osoba.jmeno%TYPE;  
v_prijmeni_pacienta osoba.prijmeni%TYPE;

  CURSOR cur_vysetreni IS
    SELECT v.id_vysetreni, v.datum, v.zprava, v.id_lekar,
           o_lek.jmeno as jmeno_lek, o_lek.prijmeni as prijmeni_lek
    FROM vysetreni v
    LEFT JOIN lekar l ON v.id_lekar = l.id_osoby
    LEFT JOIN osoba o_lek ON l.id_osoby = o_lek.id_osoby
    WHERE v.id_pacient = p_id_pacient
    ORDER BY v.datum DESC;

  v_nalezeno BOOLEAN := FALSE;

BEGIN

  BEGIN
    SELECT o.jmeno, o.prijmeni
    INTO v_jmeno_pacienta, v_prijmeni_pacienta
    FROM pacient p JOIN osoba o ON p.id_osoby = o.id_osoby
    WHERE p.id_osoby = p_id_pacient;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      DBMS_OUTPUT.PUT_LINE('Chyba: Pacient s ID ' || p_id_pacient || ' nebyl nalezen.');
      RETURN;
  END;

  DBMS_OUTPUT.PUT_LINE('--- Vyšetření pacienta: ' || v_jmeno_pacienta || ' ' || v_prijmeni_pacienta || ' (ID: ' || p_id_pacient || ') ---');


  FOR rec IN cur_vysetreni LOOP
    v_nalezeno := TRUE;


    DBMS_OUTPUT.PUT_LINE('  ID Vyšetření: ' || rec.id_vysetreni);
    DBMS_OUTPUT.PUT_LINE('  Datum: ' || TO_CHAR(rec.datum, 'DD.MM.YYYY'));
    IF rec.id_lekar IS NOT NULL THEN
        DBMS_OUTPUT.PUT_LINE('  Lékař: ' || rec.jmeno_lek || ' ' || rec.prijmeni_lek || ' (ID: ' || rec.id_lekar || ')');
    ELSE
        DBMS_OUTPUT.PUT_LINE('  Lékař: (Neznámý/Smazaný)');
    END IF;
    DBMS_OUTPUT.PUT_LINE('  Zpráva: ' || SUBSTR(rec.zprava, 1, 100) || '...');
    DBMS_OUTPUT.PUT_LINE('  --------------------');
  END LOOP;


  IF NOT v_nalezeno THEN
    DBMS_OUTPUT.PUT_LINE('Pro pacienta nebyla nalezena žádná vyšetření.');
  END IF;

EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Chyba: ' || SQLERRM);

    RAISE;
END;
/


CREATE OR REPLACE PROCEDURE zapis_nove_vysetreni (
    p_id_pacient IN pacient.id_osoby%TYPE,
    p_id_lekar   IN lekar.id_osoby%TYPE,
    p_datum      IN vysetreni.datum%TYPE,
    p_zprava     IN vysetreni.zprava%TYPE
)
AS
  v_pocet_pacient NUMBER;
  v_pocet_lekar   NUMBER;
  v_nove_id       vysetreni.id_vysetreni%TYPE;

  e_pacient_neexistuje EXCEPTION;
  PRAGMA EXCEPTION_INIT(e_pacient_neexistuje, -20002);
  e_lekar_neexistuje   EXCEPTION;
  PRAGMA EXCEPTION_INIT(e_lekar_neexistuje, -20003);
BEGIN

  SELECT COUNT(*) INTO v_pocet_pacient FROM pacient WHERE id_osoby = p_id_pacient;
  IF v_pocet_pacient = 0 THEN
    RAISE e_pacient_neexistuje;
  END IF;

  SELECT COUNT(*) INTO v_pocet_lekar FROM lekar WHERE id_osoby = p_id_lekar;
  IF v_pocet_lekar = 0 THEN
    RAISE e_lekar_neexistuje;
  END IF;

  INSERT INTO vysetreni (datum, zprava, id_pacient, id_lekar)
  VALUES (p_datum, p_zprava, p_id_pacient, p_id_lekar)
  RETURNING id_vysetreni INTO v_nove_id;

  DBMS_OUTPUT.PUT_LINE('Nové vyšetření (ID: ' || v_nove_id || ') pro pacienta ID ' || p_id_pacient || ' lékařem ID ' || p_id_lekar || ' vytvořeno.');
  COMMIT;

EXCEPTION
  WHEN e_pacient_neexistuje THEN
    DBMS_OUTPUT.PUT_LINE('Chyba (-20002): Pacient s ID ' || p_id_pacient || ' neexistuje.');
    ROLLBACK;
  WHEN e_lekar_neexistuje THEN
    DBMS_OUTPUT.PUT_LINE('Chyba (-20003): Lékař s ID ' || p_id_lekar || ' neexistuje..');
    ROLLBACK;
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Chyba: ' || SQLERRM);
    ROLLBACK;
    RAISE;
END;
/
--------------------------------------------------------------------------
-- Předvedení procedur
--------------------------------------------------------------------------
EXEC najdi_vysetreni_pacienta(p_id_pacient => 211);
EXEC najdi_vysetreni_pacienta(p_id_pacient => 75);
EXEC najdi_vysetreni_pacienta(p_id_pacient => 82);
EXEC najdi_vysetreni_pacienta(p_id_pacient => 999);
EXEC zapis_nove_vysetreni(p_id_pacient => 75, p_id_lekar => 37, p_datum => SYSDATE, p_zprava => 'Kontrolní návštěva po rehabilitaci.');
EXEC najdi_vysetreni_pacienta(p_id_pacient => 75);
EXEC zapis_nove_vysetreni(p_id_pacient => 999, p_id_lekar => 37, p_datum => SYSDATE, p_zprava => 'Test neexistujícího pacienta.');
EXEC zapis_nove_vysetreni(p_id_pacient => 75, p_id_lekar => 999, p_datum => SYSDATE, p_zprava => 'Test neexistujícího lékaře.');


--------------------------------------------------------------------------
-- EXPLAIN PLAN
--------------------------------------------------------------------------
PROMPT EXPLAIN PLAN bez indexu
EXPLAIN PLAN SET STATEMENT_ID = 'plan_no_index' FOR
    SELECT l.specializace, COUNT(*) AS pocet_receptu
    FROM recept r
    JOIN lekar l ON r.id_lekar = l.id_osoby
    GROUP BY l.specializace;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'plan_no_index'));

CREATE INDEX idx_recept_id_lekar ON recept(id_lekar);
COMMIT;

PROMPT EXPLAIN PLAN s indexem recept(id_lekar)
EXPLAIN PLAN SET STATEMENT_ID = 'plan1' FOR
    SELECT l.specializace, COUNT(*) AS pocet_receptu
    FROM recept r
    JOIN lekar l ON r.id_lekar = l.id_osoby
    GROUP BY l.specializace;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'plan1'));

CREATE INDEX idx_lekar_id_osoby_spec ON lekar(id_osoby, specializace);
COMMIT;

PROMPT EXPLAIN PLAN s indexem lekar(id_osoby, specializace)
EXPLAIN PLAN SET STATEMENT_ID = 'plan2' FOR
    SELECT l.specializace, COUNT(*) AS pocet_receptu
    FROM recept r
    JOIN lekar l ON r.id_lekar = l.id_osoby
    GROUP BY l.specializace;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'plan2'));

--------------------------------------------------------------------------
-- MATERIALIZOVANÝ POHLED
--------------------------------------------------------------------------
CREATE MATERIALIZED VIEW mv_pocet_pacientu_na_oddeleni
BUILD IMMEDIATE
REFRESH COMPLETE ON DEMAND
ENABLE QUERY REWRITE
AS
SELECT
    NVL(od.nazev, 'Neznámé oddělení') AS nazev_oddeleni,
    COUNT(DISTINCT v.id_pacient) AS pocet_pacientu
FROM vysetreni v
LEFT JOIN lekar l ON v.id_lekar = l.id_osoby
LEFT JOIN oddeleni od ON l.id_oddeleni = od.id_oddeleni
GROUP BY od.nazev;

PROMPT Obsah pohledu:
SELECT * FROM mv_pocet_pacientu_na_oddeleni ORDER BY nazev_oddeleni;

BEGIN
  zapis_nove_vysetreni(
    p_id_pacient => 99,
    p_id_lekar   => 37,
    p_datum      => SYSDATE,
    p_zprava     => 'Kontrola na Ortopedii.'
  );
END;
/

-- Úklid
DELETE FROM vysetreni WHERE id_pacient = 99 AND id_lekar = 37 AND zprava = 'Kontrola na Ortopedii.';
COMMIT;

--------------------------------------------------------------------------
-- KOMPLEXNÍ DOTAZ S WITH A CASE
--------------------------------------------------------------------------
-- Získává počet vyšetření pro všechny pacienty a kategorizuje je dle četnosti:
--   • 'Častý pacient'   – > 3 vyšetření
--   • 'Pravidelný pacient' – 1-3 vyšetření
--   • 'Nový pacient'     – 0 vyšetření
WITH ins AS (
    SELECT p.id_osoby                    AS id_pacient,
           o.jmeno,
           o.prijmeni,
           COUNT(v.id_vysetreni)          AS pocet_vysetreni
    FROM pacient p
    LEFT JOIN vysetreni v ON p.id_osoby = v.id_pacient
    LEFT JOIN osoba   o ON p.id_osoby = o.id_osoby
    GROUP BY p.id_osoby, o.jmeno, o.prijmeni
)
SELECT id_pacient,
       jmeno,
       prijmeni,
       pocet_vysetreni,
       CASE
           WHEN pocet_vysetreni > 3 THEN 'Častý pacient'
           WHEN pocet_vysetreni BETWEEN 1 AND 3 THEN 'Pravidelný pacient'
           ELSE 'Nový pacient'
       END AS kategorie
FROM ins;
--------------------------------------------------------------------------
-- DEFINICE PŘÍSTUPOVÝCH PRÁV
--------------------------------------------------------------------------
GRANT SELECT ON osoba TO xludvir00;
GRANT SELECT ON lekar TO xludvir00;
GRANT SELECT ON oddeleni TO xludvir00;
GRANT SELECT ON pacient TO xludvir00;
GRANT SELECT ON recept TO xludvir00;
GRANT SELECT ON lek TO xludvir00;
GRANT SELECT ON recept_lek TO xludvir00;
GRANT SELECT ON pacient_lek TO xludvir00;
GRANT SELECT ON vysetreni TO xludvir00;
GRANT SELECT ON audit_log_pacient TO xludvir00;

GRANT EXECUTE ON najdi_vysetreni_pacienta TO xludvir00;
GRANT EXECUTE ON zapis_nove_vysetreni TO xludvir00;


COMMIT;