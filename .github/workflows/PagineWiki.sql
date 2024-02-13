CREATE TABLE Utente(
IdUtente    SERIAL          NOT NULL,
Email       VARCHAR(128)    NOT NULL,
Password    VARCHAR(128)    NOT NULL,
CONSTRAINT PK_Utente PRIMARY KEY (IdUtente),
CONSTRAINT UK_Utente UNIQUE (Email));

CREATE TABLE Pagina(
IdPagina    SERIAL          NOT NULL,
Titolo      VARCHAR(128)    NOT NULL,
NumVisite	INT             DEFAULT 0,
Data        DATE            DEFAULT current_date,
Ora         TIME            DEFAULT localtime,
IdAutore    INT,
CONSTRAINT PK_Pagina PRIMARY KEY (IdPagina),
CONSTRAINT FK_Pagina FOREIGN KEY (IdAutore) REFERENCES Utente(IdUtente) 
    ON DELETE SET NULL      ON UPDATE CASCADE,
CONSTRAINT UK_Pagina UNIQUE (Titolo));

CREATE TABLE Frase(
IdFrase     SERIAL		   NOT NULL,
Stringa		VARCHAR(500)	NOT NULL,
Posizione	INT             NOT NULL,
Visibile    BOOL            DEFAULT NULL,
Accettata	BOOL            DEFAULT NULL,
Data        DATE            DEFAULT current_date,
Ora         TIME            DEFAULT localtime,
IdPagina    SERIAL          NOT NULL,
IdUtente    INT,
IdLink      INT             DEFAULT NULL,
IdAutore    INT,
CONSTRAINT PK_Frase PRIMARY KEY (IdFrase),
CONSTRAINT FK_Frase_Pagina FOREIGN KEY (IdPagina) REFERENCES Pagina(IdPagina)
    ON DELETE CASCADE      ON UPDATE CASCADE,
CONSTRAINT FK_Frase_Link FOREIGN KEY (IdLink) REFERENCES Pagina(IdPagina)
    ON DELETE SET NULL      ON UPDATE CASCADE,
CONSTRAINT FK_Frase_Utente FOREIGN KEY (IdUtente) REFERENCES Utente(IdUtente)
    ON DELETE SET NULL      ON UPDATE CASCADE,
CONSTRAINT FK_Frase_Autore FOREIGN KEY (IdAutore) REFERENCES Utente(IdUtente)
    ON DELETE SET NULL      ON UPDATE CASCADE);

CREATE TABLE Visita(
IdPagina    INT		NOT NULL,
IdUtente    INT,
CONSTRAINT FK_Visita_Pagina FOREIGN KEY (IdPagina) REFERENCES Pagina(IdPagina)
    ON DELETE CASCADE      ON UPDATE CASCADE,
CONSTRAINT FK_Visita_Utente FOREIGN KEY (IdUtente) REFERENCES Utente(IdUtente)
    ON DELETE SET NULL     ON UPDATE CASCADE);

ALTER TABLE frase ADD CONSTRAINT check_lunghezza_frase CHECK (LENGTH(stringa)>1); 
ALTER TABLE frase ADD CONSTRAINT check_carattere_frase CHECK (regexp_match(stringa, '[a-z]') IS NOT NULL OR regexp_match(stringa, '[A-Z]') IS NOT NULL);
ALTER TABLE pagina ADD CONSTRAINT check_lunghezza_titolo CHECK (LENGTH(titolo)>0);

ALTER TABLE frase ADD CONSTRAINT check_visibile_accettata
    CHECK (
        (visibile = accettata) OR
        (accettata = TRUE AND visibile = FALSE)
    );

ALTER TABLE utente ADD CONSTRAINT check_email CHECK (email LIKE '_%@_%._%');

CREATE OR REPLACE FUNCTION fun_upper_titolo() RETURNS TRIGGER AS
$$
DECLARE
BEGIN
        NEW.titolo = UPPER(TRIM(NEW.titolo));
        RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trig_upper_titolo
BEFORE INSERT OR UPDATE OF titolo
ON pagina
FOR EACH ROW
EXECUTE FUNCTION fun_upper_titolo();

/*TEST
INSERT INTO Pagina(Titolo, IdAutore) VALUES ('I geroglifici', 1);
SELECT * FROM pagina;*/




CREATE OR REPLACE FUNCTION fun_punto() RETURNS TRIGGER AS
$$
DECLARE
BEGIN
    -- Aggiungi un punto finale se non presente
    IF RIGHT(TRIM(NEW.stringa), 1) <> '.' THEN
        NEW.stringa = TRIM(NEW.stringa) || '.';
    ELSE
        NEW.stringa = TRIM(NEW.stringa);
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trig_punto
BEFORE INSERT OR UPDATE OF stringa
ON frase
FOR EACH ROW
EXECUTE FUNCTION fun_punto();

/*TEST
--Punto Mancante
INSERT INTO Frase(Stringa, Posizione, IdPagina, IdUtente) VALUES ('Il videogioco è un gioco gestito da un dispositivo elettronico che consente di interagire con le immagini di uno schermo', 1, 3, 3);
--Spazi in Eccesso
INSERT INTO Frase(Stringa, Posizione, IdPagina, IdUtente) VALUES ('Il termine generalmente tende a identificare un software, ma in alcuni casi può riferirsi anche a un dispositivo hardware dedicato a uno specifico gioco.   ', 2, 3, 3);*/




CREATE OR REPLACE FUNCTION fun_autore_frase()
RETURNS TRIGGER AS
$$
BEGIN
    NEW.idautore = (SELECT idautore FROM pagina WHERE idpagina = NEW.idpagina);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trig_autore_frase
BEFORE INSERT ON frase
FOR EACH ROW 
EXECUTE FUNCTION fun_autore_frase();

/*TEST
INSERT INTO Frase(Stringa, Posizione, IdPagina, IdUtente) VALUES ('Il videogioco è un gioco gestito da un dispositivo elettronico che consente di interagire con le immagini di uno schermo.', 1, 3, 3);
INSERT INTO Frase(Stringa, Posizione, IdPagina, IdUtente) VALUES ('Il termine generalmente tende a identificare un software, ma in alcuni casi può riferirsi anche a un dispositivo hardware dedicato a uno specifico gioco.', 2, 3, 3);*/




CREATE OR REPLACE FUNCTION fun_ins_frase() RETURNS TRIGGER AS
$$
BEGIN
    --Caso in cui la modifica sia dell'autore
    IF NEW.idutente = NEW.idautore THEN
        --Attiva la proposta
        NEW.accettata := true;
        NEW.visibile := true;
        --Disattiva frase visibile al momento
        UPDATE frase
        SET visibile = FALSE
        WHERE idpagina = NEW.idpagina 
            AND posizione = NEW.posizione 
            AND visibile;
    --Caso in cui sia di un altro utente
    ELSE
        NEW.accettata := NULL;
        NEW.visibile := NULL;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trig_ins_frase
BEFORE INSERT OR UPDATE OF idautore 
ON frase
FOR EACH ROW
EXECUTE FUNCTION fun_ins_frase();

/*TEST
INSERT INTO Frase(Stringa, Posizione, IdPagina, IdUtente) VALUES ('Il videogioco è un gioco gestito da un dispositivo elettronico che consente di interagire con le immagini di uno schermo.', 1, 3, 3);
INSERT INTO Frase(Stringa, Posizione, IdPagina, IdUtente) VALUES ('Il termine generalmente tende a identificare un software, ma in alcuni casi può riferirsi anche a un dispositivo hardware dedicato a uno specifico gioco.', 2, 3, 4);*/




CREATE OR REPLACE FUNCTION fun_visibile()
RETURNS TRIGGER AS
$$
BEGIN
    IF (NEW.accettata = TRUE) THEN
        NEW.visibile := TRUE;
        --Disattiva frase visibile al momento
        UPDATE frase
        SET visibile = FALSE
        WHERE idpagina = NEW.idpagina 
            AND posizione = NEW.posizione 
            AND visibile;
    ELSEIF (NEW.accettata = FALSE) THEN
        NEW.visibile := FALSE;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trig_check_bit
AFTER UPDATE OF accettata
ON frase
FOR EACH ROW 
EXECUTE FUNCTION fun_visibile();

/*TEST
INSERT INTO Frase(Stringa, Posizione, IdPagina, IdUtente) VALUES ('Il videogioco è un gioco gestito da un dispositivo elettronico che consente di interagire con le immagini di uno schermo.', 1, 3, 3);
INSERT INTO Frase(Stringa, Posizione, IdPagina, IdUtente) VALUES ('Il videogioco è un gioco gestito da un dispositivo elettronico che consente di interagire con le immagini di uno schermo.', 1, 3, 5);

UPDATE frase
SET accettata = TRUE
WHERE idfrase=5;*/



CREATE OR REPLACE FUNCTION fun_link_dom() RETURNS TRIGGER AS
$$
DECLARE
BEGIN
    /*Ricrodiamo che i titoli delle pagine sono in maiuscolo, per questo usiamo la funzione UPPER nel confronto tra stringhe*/
     IF NEW.idlink IS NULL OR (NEW.idlink IS NOT NULL AND POSITION((SELECT titolo FROM pagina WHERE idpagina = NEW.idlink) IN UPPER(NEW.stringa)) <> 0) THEN
        RETURN NEW;
    ELSE
        RETURN NULL;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trig_link_dom
BEFORE INSERT OR UPDATE OF idlink
ON frase
FOR EACH ROW
EXECUTE FUNCTION fun_link_dom();

/*TEST
--Titolo della quarta Pagina: "ALESSANDRO MANZONI"
INSERT INTO Frase(Stringa, Posizione, IdPagina, IdLink, IdUtente) VALUES ('I promessi sposi sono un celebre romanzo storico di Alessandro Manzoni, ritenuto il più famoso e il più letto tra quelli scritti in lingua italiana.', 1, 6, 4, 6);*/



CREATE OR REPLACE FUNCTION fun_ins_visita() RETURNS TRIGGER AS
$$
DECLARE
BEGIN
    --Ci assicuriamo che le visite dell'autore non pesino nel conteggio
    IF NEW.idutente <> (SELECT idautore FROM pagina WHERE idpagina = NEW.idpagina) THEN
        UPDATE pagina
        SET numvisite = numvisite+1
        WHERE idpagina = NEW.idpagina;
    END IF;
        
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trig_ins_visita
AFTER INSERT ON visita
FOR EACH ROW
EXECUTE FUNCTION fun_ins_visita();

/*TEST
INSERT INTO Visita(IdPagina, IdUtente) VALUES (1, 1);
INSERT INTO Visita(IdPagina, IdUtente) VALUES (1, 11);*/



CREATE OR REPLACE FUNCTION ins_frasi_originali (
    IN itesto varchar(2000),
    IN ipagina pagina.idpagina%TYPE,
    IN iutente utente.idutente%TYPE
) RETURNS void AS
$$
DECLARE
    occ integer := 0;
BEGIN
    LOOP
        occ := occ + 1;
        --Termina quando arriva all'ultima frase
        EXIT WHEN SPLIT_PART(itesto, '.', occ) = SPLIT_PART(itesto, '.', -1);
        
        -- Elimina gli spazi dopo il punto con la funzione TRIM e aggiunge il punto finale
        INSERT INTO frase (Stringa, Posizione, IdPagina, IdUtente, IdAutore)
        VALUES (TRIM(SPLIT_PART(itesto, '.', occ)) || '.', occ, ipagina, iutente, iutente);
    END LOOP;
    
    RETURN;
END;
$$ LANGUAGE plpgsql;

/*TEST
SELECT ins_frasi_originali('Il panda gigante o panda maggiore (Ailuropoda melanoleuca) è un mammifero appartenente alla famiglia degli ursidi. Originario della Cina centrale, vive nelle regioni montuose del Sichuan; è divenuto, verso la seconda metà del XX secolo, un emblema nazionale cinese, dal 1982 raffigurato sulle monete auree cinesi (serie Panda Dorato), oltre che simbolo del WWF. Il nome scientifico è Ailuropoda melanoleuca, dal greco antico che significa letteralmente piede di gatto - nero bianco. Esso è imparentato alla lontana con il panda rosso, ma la somiglianza tra i due nomi sembra più che altro provenire dalla comune alimentazione basata sul bambù, dalle tipiche macchie nere intorno agli occhi e dal cosiddetto "falso pollice". Il tasso di natalità del panda è molto basso, sia allo stato naturale sia in cattività: la femmina alleva soltanto un piccolo e, se partorisce due gemelli, non riesce ad occuparsi di entrambi ma si occupa di uno solo.', 2, 2);

SELECT * FROM frase WHERE idpagina = 2 ORDER BY posizione;*/



CREATE OR REPLACE VIEW pagine_frasi_visibili AS
SELECT 
    l.titolo, 
    f.posizione, 
    f.stringa, 
    f.idpagina, 
    n.titolo AS collegamento
FROM 
    (frase AS f JOIN pagina AS l ON l.idpagina=f.idpagina) 
    LEFT OUTER JOIN pagina AS n ON f.idlink=n.idpagina
WHERE 
    f.visibile=true
ORDER BY 
    f.idpagina, 
    f.posizione;

CREATE OR REPLACE FUNCTION ricerca_pagina_visibile(IN ricerca pagina.idpagina%TYPE) 
RETURNS TABLE(
    pagina character varying, 
    testo character varying, 
    link character varying
) AS
$$
DECLARE
BEGIN
    RETURN QUERY
        SELECT titolo, stringa, collegamento
        FROM pagine_frasi_visibili
        WHERE idpagina=ricerca;
END;
$$ LANGUAGE plpgsql;

/*TEST
SELECT * FROM ricerca_pagina_visibile(2);*/



CREATE OR REPLACE VIEW pagine_con_storico AS
SELECT 
    l.titolo, 
    f.posizione, 
    f.visibile, 
    f.accettata, 
    f.stringa, 
    l.idpagina, 
    l.idautore, 
    n.titolo AS collegamento
FROM 
    (frase AS f JOIN pagina AS l ON l.idpagina=f.idpagina) 
    LEFT OUTER JOIN pagina AS n ON f.idlink=n.idpagina
/*Controllo per scartare le proposte non ancora visionate con accettata e visibile = NULL*/
WHERE 
    f.accettata IS NOT NULL
ORDER BY 
    l.idpagina ASC, 
    f.posizione ASC, 
    f.visibile DESC, 
    f.accettata DESC,
    f.data DESC,
    f.ora DESC;

CREATE OR REPLACE FUNCTION ricerca_storico_autore(
    IN ricerca pagina.idautore%TYPE
) 
RETURNS TABLE(
    pagina character varying, 
    posizione frase.posizione%TYPE, 
    visibile frase.visibile%TYPE, 
    accettata frase.accettata%TYPE, 
    testo character varying,
    collegamento character varying
) AS
$$
DECLARE
BEGIN
    RETURN QUERY
        SELECT s.titolo, s.posizione, s.visibile, s.accettata, s.stringa, s.collegamento
        FROM  pagine_con_storico AS s
        WHERE s.idautore = ricerca;
END;
$$ LANGUAGE plpgsql;

/*TEST
SELECT * FROM ricerca_storico_autore(2);*/



CREATE OR REPLACE VIEW proposte AS
SELECT 
    l.titolo, 
    l.idpagina, 
    f.posizione, 
    f.stringa AS proposta,
    l.idautore, 
    n.titolo AS collegamento,
    v.stringa AS attiva
FROM 
    frase AS f 
JOIN pagina AS l ON l.idpagina = f.idpagina
LEFT JOIN frase AS v ON v.idpagina = f.idpagina AND v.posizione = f.posizione AND v.visibile IS TRUE
LEFT JOIN pagina AS n ON f.idlink = n.idpagina
WHERE 
    f.accettata IS NULL
ORDER BY 
    l.idpagina ASC, 
    f.posizione ASC,
    f.data DESC,
    f.ora DESC;

CREATE OR REPLACE FUNCTION proposte_autore(
    IN ricerca pagina.idautore%TYPE
) 
RETURNS TABLE(      
    pagina character varying, 
    posizione frase.posizione%TYPE, 
    visibile character varying,
    proposta character varying,
    collegamento character varying
) AS
$$
BEGIN
    RETURN QUERY
        SELECT s.titolo, s.posizione, s.attiva, s.proposta, s.collegamento
        FROM proposte AS s
        WHERE s.idautore = ricerca;
END;
$$ LANGUAGE plpgsql;

/*TEST
SELECT * FROM proposte_autore(2);*/



CREATE OR REPLACE VIEW tutte_proposte AS
SELECT 
    l.titolo, 
    l.idpagina, 
    f.posizione, 
    f.visibile,
    f.accettata,
    f.stringa AS proposta,
    f.idautore,
    f.idutente,
    n.titolo AS collegamento
FROM 
    frase AS f 
JOIN pagina AS l ON l.idpagina = f.idpagina
LEFT JOIN pagina AS n ON f.idlink = n.idpagina
WHERE f.idutente <> f.idautore
ORDER BY 
    l.idpagina ASC, 
    f.posizione ASC,
    f.data DESC,
    f.ora DESC;

CREATE OR REPLACE FUNCTION tutte_proposte_utente(
    IN ricerca pagina.idautore%TYPE
) 
RETURNS TABLE(      
    pagina character varying, 
    posizione frase.posizione%TYPE, 
    visibile boolean,
    accettata boolean,
    proposta character varying,
    collegamento character varying
) AS
$$
BEGIN
    RETURN QUERY
        SELECT s.titolo, s.posizione, s.visibile, s.accettata, s.proposta, s.collegamento
        FROM tutte_proposte AS s
        WHERE s.idutente = ricerca;
END;
$$ LANGUAGE plpgsql;

/*TEST
INSERT INTO Frase(Stringa, Posizione, IdPagina, IdUtente) VALUES ('Un glifo, dal greco γλύφω (glýphō), «incidere», in origine indicava un qualsiasi segno, inciso o dipinto, come ad esempio i glifi della scrittura maya o di quella egizia, conosciuti meglio come geroglifici (dal greco iéros + glýphōs, «segni sacri»), a indicare una lingua divina sapienziale.', 1, 3, 5);
INSERT INTO Frase(Stringa, Posizione, IdPagina, IdUtente) VALUES ('Storicamente ai glifi era attribuito un potere magico ed evocativo di tipo analogico, per il quale essi venivano utilizzati all''interno di formule magiche, oppure come simboli di segni zodiacali e pianeti dell''astrologia, di elementi dell''alchimia, o di entità mitologico-religiose.', 2, 3, 5);
INSERT INTO Frase(Stringa, Posizione, IdPagina, IdUtente) VALUES ('In tipografia, un glifo è una rappresentazione concreta di un grafema, di più grafemi o di parte di un grafema, senza porre attenzione alle caratteristiche stilistiche.', 3, 3, 5);
INSERT INTO Frase(Stringa, Posizione, IdPagina, IdUtente) VALUES ('Parallelamente, il termine carattere si riferisce a un grafema nell''ambito tipografico e informatico.', 4, 6, 5);
INSERT INTO Frase(Stringa, Posizione, IdPagina, IdUtente) VALUES ('Mentre un grafema è un''unità di testo, un glifo è un''unità grafica.', 5, 6, 5);
SELECT * FROM tutte_proposte_utente(5);*/



CREATE OR REPLACE VIEW classifica_pagine AS
SELECT n.numvisite AS visualizzazioni, n.titolo, u.email AS autore
FROM pagina n JOIN utente u ON n.idautore = u.idutente
ORDER BY n.numvisite DESC, n.titolo ASC;

/*TEST
SELECT * FROM classifica_pagine;*/



CREATE OR REPLACE FUNCTION fun_del_autore() RETURNS TRIGGER AS
$$
DECLARE 
BEGIN
    --Verifica se l'autore eliminato ha creato qualche pagina
    IF OLD.idutente IN (SELECT idautore FROM pagina) THEN 
        --Verifica che ci siano delle proposte
        IF NOT EXISTS (SELECT idutente FROM frase WHERE idautore = OLD.idutente) THEN
            RETURN OLD;
        ELSE
            UPDATE pagina
            SET idautore = (
                SELECT idutente
                FROM (
                    SELECT idutente, COUNT(*) AS count_interazione
                    FROM frase
                    WHERE idutente IS NOT NULL AND 
                      idutente <> OLD.idutente AND 
                      idautore = OLD.idutente
                    GROUP BY idutente
                    ORDER BY COUNT(*) DESC
                    FETCH FIRST ROW ONLY))
            WHERE idautore = OLD.idutente;
            
        END IF;
    END IF;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trig_del_autore
BEFORE DELETE ON utente
FOR EACH ROW
EXECUTE FUNCTION fun_del_autore();

/*TEST
Nel database sono presenti due proposte da parte dell'utente con idutente=5 e tre da parte di quello con idutente=3, per la pagina dell'autore con idutente=2 e idpagina=2.
DELETE FROM utente
WHERE idutente=2;

SELECT * FROM pagina WHERE idpagina=2;*/



CREATE OR REPLACE FUNCTION fun_autore_new() RETURNS TRIGGER AS 
$$
BEGIN
    IF NEW.idautore <> OLD.idautore AND NEW.idautore IS NOT NULL THEN
        UPDATE frase
        SET idautore = NEW.idautore
        WHERE idpagina = NEW.idpagina;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trig_autore_new
AFTER UPDATE OF idautore
ON public.pagina
FOR EACH ROW
EXECUTE FUNCTION fun_autore_new();

    
CREATE OR REPLACE FUNCTION fun_autore_null() RETURNS TRIGGER AS
$$
DECLARE
BEGIN
    IF NEW.idautore IS NULL THEN
        UPDATE frase
	SET idautore = NEW.idutente
	WHERE idpagina = NEW.idpagina;
	UPDATE pagina
	SET idautore = NEW.idutente
	WHERE idpagina = NEW.idpagina;
        --setto i valori per la tupla appena inserita manualmente
        NEW.idautore := NEW.idutente;
        NEW.accettata := TRUE;
        NEW.visibile := TRUE;
    END IF;
	
RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trig_autore_null
BEFORE INSERT ON frase
FOR EACH ROW
EXECUTE FUNCTION fun_autore_null();

/*TEST 1
--continuo del test precedente
SELECT * FROM frase WHERE idpagina=2;

--TEST 2
--il database non presenta alcuna proposta per la pagina con idpagina=1
DELETE FROM utente WHERE idutente=1;
INSERT INTO Frase(Stringa, Posizione, IdPagina, IdUtente) VALUES ('Un glifo, dal greco γλύφω (glýphō), «incidere», in origine indicava un qualsiasi segno, inciso o dipinto, come ad esempio i glifi della scrittura maya o di quella egizia, conosciuti meglio come geroglifici (dal greco iéros + glýphōs, «segni sacri»), a indicare una lingua divina sapienziale.', 1, 1, 5);
SELECT * FROM frase WHERE idpagina=1;*/


--POPOLAMENTO

--Tabella UTENTE
INSERT INTO Utente(Email, Password) VALUES ('alessia@gmail.com', 'Alessia123');
INSERT INTO Utente(Email, Password) VALUES ('martina@gmail.com', 'Martina456');
INSERT INTO Utente(Email, Password) VALUES ('massimo@gmail.com', 'Massimo789');
INSERT INTO Utente(Email, Password) VALUES ('antonio@gmail.com', 'Antonio123');
INSERT INTO Utente(Email, Password) VALUES ('giulia@gmail.com', 'Giulia456');
INSERT INTO Utente(Email, Password) VALUES ('miriam@gmail.com', 'Miriam789');
INSERT INTO Utente(Email, Password) VALUES ('mario@gmail.com', 'Mario123');
INSERT INTO Utente(Email, Password) VALUES ('simone@gmail.com', 'Simone456');
INSERT INTO Utente(Email, Password) VALUES ('emanuele@gmail.com', 'Emmanuele!');
INSERT INTO Utente(Email, Password) VALUES ('andrea@gmail.com', 'Andrea123');
INSERT INTO Utente(Email, Password) VALUES ('claudio@gmail.com', 'Claudio456');
INSERT INTO Utente(Email, Password) VALUES ('giuseppe@gmail.com', 'Giuseppe789');
INSERT INTO Utente(Email, Password) VALUES ('lorenzo@gmail.com', 'Lorenzo123');
INSERT INTO Utente(Email, Password) VALUES ('anna@gmail.com', 'Anna456');
INSERT INTO Utente(Email, Password) VALUES ('rebecca@gmail.com', 'Rebecca789');
INSERT INTO Utente(Email, Password) VALUES ('ciro@gmail.com', 'Ciro123');
INSERT INTO Utente(Email, Password) VALUES ('gennaro@gmail.com', 'Gennaro456');
INSERT INTO Utente(Email, Password) VALUES ('silvio@gmail.com', 'Silvio789');
INSERT INTO Utente(Email, Password) VALUES ('mariano@gmail.com', 'Mariano123');
INSERT INTO Utente(Email, Password) VALUES ('antonella@gmail.com', 'Antonella?');

--Tabella PAGINA
INSERT INTO Pagina(Titolo, IdAutore) VALUES ('I geroglifici', 1);
INSERT INTO Pagina(Titolo, IdAutore) VALUES ('I Panda', 2);
INSERT INTO Pagina(Titolo, IdAutore) VALUES ('I videogiochi', 3);
INSERT INTO Pagina(Titolo, IdAutore) VALUES ('Alessandro Manzoni', 4);
INSERT INTO Pagina(Titolo, IdAutore) VALUES ('Apple', 5);
INSERT INTO Pagina(Titolo, IdAutore) VALUES ('I Promessi Sposi', 6);
INSERT INTO Pagina(Titolo, IdAutore) VALUES ('Microsoft', 7);

--Tabella FRASE
--I geroglifici
INSERT INTO Frase(Stringa, Posizione, IdPagina, IdUtente) VALUES ('Un glifo in origine indicava un qualsiasi segno, inciso o dipinto, come ad esempio i glifi della scrittura maya o di quella egizia, conosciuti meglio come geroglifici (dal greco iéros + glýphōs, «segni sacri»), a indicare una lingua divina sapienziale.', 1, 1, 1);
INSERT INTO Frase(Stringa, Posizione, IdPagina, IdUtente) VALUES ('Storicamente ai glifi era attribuito un potere magico ed evocativo di tipo analogico, per il quale essi venivano utilizzati all''interno di formule magiche, oppure come simboli di segni zodiacali e pianeti dell''astrologia, di elementi dell''alchimia, o di entità mitologico-religiose.', 2, 1, 1);
INSERT INTO Frase(Stringa, Posizione, IdPagina, IdUtente) VALUES ('In tipografia, un glifo e una rappresentazione concreta di un grafema, di più grafemi o di parte di un grafema, senza porre attenzione alle caratteristiche stilistiche.', 3, 1, 1);
INSERT INTO Frase(Stringa, Posizione, IdPagina, IdUtente) VALUES ('Parallelamente, il termine carattere si riferisce a un grafema nell''ambito tipografico e informatico.', 4, 1, 1);
INSERT INTO Frase(Stringa, Posizione, IdPagina, IdUtente) VALUES ('Mentre un grafema è un''unità di testo, un glifo è un''unità grafica.', 5, 1, 1);

--I Panda
INSERT INTO Frase(Stringa, Posizione, IdPagina, IdUtente) VALUES ('Il panda gigante o panda maggiore è un mammifero appartenente alla famiglia degli ursidi.', 1, 2, 2);
INSERT INTO Frase(Stringa, Posizione, IdPagina, IdUtente) VALUES ('Originario della Cina centrale, vive nelle regioni montuose del Sichuan; è divenuto, verso la seconda metà del XX secolo, un emblema nazionale cinese, dal 1982 raffigurato sulle monete auree cinesi (serie Panda Dorato), oltre che simbolo del WWF.', 2, 2, 2);
INSERT INTO Frase(Stringa, Posizione, IdPagina, IdUtente) VALUES ('Il nome scientifico è Ailuropoda melanoleuca, dal greco antico che significa letteralmente piede di gatto - nero bianco.', 3, 2, 2);
INSERT INTO Frase(Stringa, Posizione, IdPagina, IdUtente) VALUES ('Esso è imparentato alla lontana con il panda rosso, ma la somiglianza tra i due nomi sembra più che altro provenire dalla comune alimentazione basata sul bambù, dalle tipiche macchie nere intorno agli occhi e dal cosiddetto "falso pollice".', 4, 2, 2);
INSERT INTO Frase(Stringa, Posizione, IdPagina, IdUtente) VALUES ('Il tasso di natalità del panda è molto basso, sia allo stato naturale sia in cattività.', 5, 2, 2);

-- I Videogiochi
INSERT INTO Frase(Stringa, Posizione, IdPagina, IdUtente) VALUES ('Il videogioco è un gioco gestito da un dispositivo elettronico che consente di interagire con le immagini di uno schermo.', 1, 3, 3);
INSERT INTO Frase(Stringa, Posizione, IdPagina, IdUtente) VALUES ('Il termine generalmente tende a identificare un software.', 2, 3, 3);
INSERT INTO Frase(Stringa, Posizione, IdPagina, IdUtente) VALUES ('Nato a partire dagli anni cinquanta del Novecento negli ambienti di ricerca scientifica e nelle facoltà universitarie americane, il videogioco ha avuto il suo sviluppo commerciale a partire dagli anni settanta.', 3, 3, 3);
INSERT INTO Frase(Stringa, Posizione, IdPagina, IdUtente) VALUES ('Nel 1952 nei laboratori dell''Università di Cambridge A.S. Douglas, come esempio per la sua tesi di dottorato, realizzò OXO, la trasposizione del gioco tris per computer.', 4, 3, 3);
INSERT INTO Frase(Stringa, Posizione, IdPagina, IdUtente) VALUES ('Nel 1958 il fisico Willy Higinbotham del Brookhaven National Laboratory, notando lo scarso interesse che avevano gli studenti per la materia, realizzò un gioco, Tennis for Two, che aveva il compito di simulare le leggi fisiche che si potevano riscontrare in un incontro di tennis: il mezzo utilizzato era un oscilloscopio.', 5, 3, 3);

--Alessandro Manzoni
INSERT INTO Frase(Stringa, Posizione, IdPagina, IdUtente) VALUES ('Alessandro Manzoni (Milano, 7 marzo 1785 – Milano, 22 maggio 1873) è stato uno scrittore, poeta e drammaturgo italiano.', 1, 4, 4);
INSERT INTO Frase(Stringa, Posizione, IdPagina, IdUtente) VALUES ('Considerato uno dei maggiori romanzieri italiani di tutti i tempi per il suo celebre romanzo I promessi sposi, caposaldo della letteratura italiana, manzoni ebbe il merito principale di aver gettato le basi per il romanzo moderno e di aver così patrocinato l''unità linguistica italiana, sulla scia di quella letteratura moralmente e civilmente impegnata propria dell''Illuminismo italiano.', 2, 4, 4);
INSERT INTO Frase(Stringa, Posizione, IdPagina, IdUtente) VALUES ('Passato dalla temperie neoclassica a quella romantica, il Manzoni, divenuto fervente cattolico dalle tendenze liberali, lasciò un segno indelebile anche nella storia del teatro italiano e in quella poetica.', 3, 4, 4);
INSERT INTO Frase(Stringa, Posizione, IdPagina, IdUtente) VALUES ('Il successo e i numerosi riconoscimenti pubblici e accademici si affiancarono a una serie di problemi di salute (nevrosi, agorafobia) e famigliari (i numerosi lutti che afflissero la vita domestica dello scrittore) che lo ridussero in un progressivo isolamento esistenziale.', 4, 4, 4);
INSERT INTO Frase(Stringa, Posizione, IdPagina, IdUtente) VALUES ('I promessi sposi sono un celebre romanzo storico di Alessandro Manzoni, ritenuto il più famoso e il più letto tra quelli scritti in lingua italiana.', 5, 4, 4);

--Apple
INSERT INTO Frase(Stringa, Posizione, IdPagina, IdUtente, IdLink) VALUES ('Apple Inc è un''azienda multinazionale statunitense che produce sistemi operativi, smartphone, computer e dispositivi multimediali, con sede a Cupertino, in California. È considerata una delle società tecnologiche Big Tech, assieme ad Amazon e Microsoft.', 1, 5, 5, 7);
INSERT INTO Frase(Stringa, Posizione, IdPagina, IdUtente) VALUES ('La società fu fondata nel 1976 da Steve Jobs, Steve Wozniak e Ronald Wayne a Los Altos, nella Silicon Valley, in California, per sviluppare e vendere il personal computer Apple I di Wozniak, sebbene Wayne abbia venduto la sua quota nei dodici giorni successivi.', 2, 5, 5);
INSERT INTO Frase(Stringa, Posizione, IdPagina, IdUtente) VALUES ('Fu incorporata come Apple Computer Inc nel gennaio 1977 e le vendite dei suoi computer, tra cui l''Apple II, crebbero rapidamente.', 3, 5, 5);
INSERT INTO Frase(Stringa, Posizione, IdPagina, IdUtente) VALUES ('Con l''espansione e l''evoluzione del mercato dei personal computer negli anni novanta, Apple ha perso quote di mercato a causa del duopolio a basso costo di Microsoft Windows sui cloni di PC Intel.', 4, 5, 5);
INSERT INTO Frase(Stringa, Posizione, IdPagina, IdUtente) VALUES ('Per riconoscere il meglio dei suoi dipendenti, Apple ha creato il programma Apple Fellows che premia le persone che forniscono straordinari contributi tecnici o di leadership al personal computer mentre sono in azienda.', 5, 5, 5);

--I Promessi Sposi
INSERT INTO Frase(Stringa, Posizione, IdPagina, IdLink, IdUtente) VALUES ('I promessi sposi sono un celebre romanzo storico di Alessandro Manzoni, ritenuto il più famoso e il più letto tra quelli scritti in lingua italiana.', 1, 6, 4, 6);
INSERT INTO Frase(Stringa, Posizione, IdPagina, IdUtente) VALUES ('Preceduto dal Fermo e Lucia, spesso considerato romanzo a sé, fu pubblicato in una prima versione tra il 1825 e il 1827; rivisto in seguito dallo stesso autore, soprattutto nel linguaggio, fu ripubblicato nella versione definitiva tra il 1840 e il 1842.', 2, 6, 6);
INSERT INTO Frase(Stringa, Posizione, IdPagina, IdUtente) VALUES ('Ambientato tra il 1628 e il 1630 in Lombardia, durante il dominio spagnolo, fu il primo esempio di romanzo storico della letteratura italiana.', 3, 6, 6);
INSERT INTO Frase(Stringa, Posizione, IdPagina, IdUtente) VALUES ('Il romanzo si basa su una rigorosa ricerca storica e gli episodi del XVII secolo, come ad esempio le vicende della monaca di Monza (Marianna de Leyva y Marino) e la Grande Peste del 1629–1631, si fondano su documenti d''archivio e cronache dell''epoca.', 4, 6, 6);
INSERT INTO Frase(Stringa, Posizione, IdPagina, IdUtente) VALUES ('Il romanzo di Manzoni viene considerato non solo una pietra miliare della letteratura italiana - in quanto è il primo romanzo moderno di questa tradizione letteraria - ma anche un passaggio fondamentale nella nascita stessa della lingua italiana.', 5, 6, 6);

--Microsoft
INSERT INTO Frase(Stringa, Posizione, IdPagina, IdUtente) VALUES ('Microsoft Corporation è un''azienda multinazionale statunitense d''informatica con sede a Redmond nello Stato di Washington (Stati Uniti)', 1, 7, 7);
INSERT INTO Frase(Stringa, Posizione, IdPagina, IdUtente) VALUES (' Creata da Bill Gates e Paul Allen il 4 aprile 1975, cambiò nome il 25 giugno 1981, per poi assumere nuovamente nel 1983 l''attuale denominazione.', 2, 7, 7);
INSERT INTO Frase(Stringa, Posizione, IdPagina, IdUtente) VALUES ('Microsoft è una delle più importanti al mondo nel settore, nonché una delle più grandi produttrici di software al mondo per fatturato, e anche una delle più grandi aziende per capitalizzazione azionaria, circa 2288 miliardi di dollari nel 2022; attualmente sviluppa, produce, supporta e vende, o concede in licenza, computer software, elettronica di consumo, personal computer e servizi.', 3, 7, 7);
INSERT INTO Frase(Stringa, Posizione, IdPagina, IdUtente) VALUES ('La storia della Microsoft Corporation ha inizio nel 1975, quando Bill Gates e Paul Allen propongono alla Micro Instrumentation and Telemetry Systems (MITS), società che ha sviluppato uno dei primi microcomputer, l''Altair 8800, di utilizzare il linguaggio di programmazione BASIC che secondo Allen e Gates funziona su quella macchina.', 4, 7, 7);
INSERT INTO Frase(Stringa, Posizione, IdPagina, IdUtente) VALUES ('In effetti la versione del Basic sviluppata da Allen e Gates funziona e nel febbraio dello stesso anno la diedero in licenza alla MITS, della quale Paul Allen diventa direttore del software.', 5, 7, 7);

--Tabella VISITA
INSERT INTO Visita(IdPagina, IdUtente) VALUES (1, 1);
INSERT INTO Visita(IdPagina, IdUtente) VALUES (1, 11);
INSERT INTO Visita(IdPagina, IdUtente) VALUES (1, 15);
INSERT INTO Visita(IdPagina, IdUtente) VALUES (1, 20);
INSERT INTO Visita(IdPagina, IdUtente) VALUES (2, 2);
INSERT INTO Visita(IdPagina, IdUtente) VALUES (2, 12);
INSERT INTO Visita(IdPagina, IdUtente) VALUES (2, 18);
INSERT INTO Visita(IdPagina, IdUtente) VALUES (2, 8);
INSERT INTO Visita(IdPagina, IdUtente) VALUES (2, 5);
INSERT INTO Visita(IdPagina, IdUtente) VALUES (2, 1);
INSERT INTO Visita(IdPagina, IdUtente) VALUES (3, 3);
INSERT INTO Visita(IdPagina, IdUtente) VALUES (3, 20);
INSERT INTO Visita(IdPagina, IdUtente) VALUES (4, 4);
INSERT INTO Visita(IdPagina, IdUtente) VALUES (4, 13);
INSERT INTO Visita(IdPagina, IdUtente) VALUES (4, 6);
INSERT INTO Visita(IdPagina, IdUtente) VALUES (4, 17);
INSERT INTO Visita(IdPagina, IdUtente) VALUES (4, 19);
INSERT INTO Visita(IdPagina, IdUtente) VALUES (4, 3);
INSERT INTO Visita(IdPagina, IdUtente) VALUES (4, 2);
INSERT INTO Visita(IdPagina, IdUtente) VALUES (4, 7);
INSERT INTO Visita(IdPagina, IdUtente) VALUES (5, 5);
INSERT INTO Visita(IdPagina, IdUtente) VALUES (6, 6);
INSERT INTO Visita(IdPagina, IdUtente) VALUES (6, 14);
INSERT INTO Visita(IdPagina, IdUtente) VALUES (6, 11);
INSERT INTO Visita(IdPagina, IdUtente) VALUES (7, 7);
INSERT INTO Visita(IdPagina, IdUtente) VALUES (7, 4);
INSERT INTO Visita(IdPagina, IdUtente) VALUES (7, 9);
INSERT INTO Visita(IdPagina, IdUtente) VALUES (7, 16);
INSERT INTO Visita(IdPagina, IdUtente) VALUES (7, 19);


--PROPOSTE DI MODIFICA
--I geroglifici
INSERT INTO Frase(Stringa, Posizione, IdPagina, IdUtente) VALUES ('Un glifo, dal greco γλύφω (glýphō), «incidere», in origine indicava un qualsiasi segno, inciso o dipinto, come ad esempio i glifi della scrittura maya o di quella egizia, conosciuti meglio come geroglifici (dal greco iéros + glýphōs, «segni sacri»), a indicare una lingua divina sapienziale.', 1, 1, 11);
INSERT INTO Frase(Stringa, Posizione, IdPagina, IdUtente) VALUES ('In tipografia, un glifo è una rappresentazione concreta di un grafema, di più grafemi o di parte di un grafema, senza porre attenzione alle caratteristiche stilistiche.', 3, 1, 11);
INSERT INTO Frase(Stringa, Posizione, IdPagina, IdUtente) VALUES ('In tipografia, un glifo è una rappresentazione concreta di un grafema, di più grafemi o di parte di un grafema, senza porre attenzione alle caratteristiche stilistiche.', 3, 1, 15);

--I Panda
INSERT INTO Frase(Stringa, Posizione, IdPagina, IdUtente) VALUES ('Il panda gigante o panda maggiore (Ailuropoda melanoleuca) è un mammifero appartenente alla famiglia degli ursidi.', 1, 2, 12);
INSERT INTO Frase(Stringa, Posizione, IdPagina, IdUtente) VALUES ('Il tasso di natalità del panda è molto basso, sia allo stato naturale sia in cattività: la femmina alleva soltanto un piccolo e, se partorisce due gemelli, non riesce ad occuparsi di entrambi ma si occupa di uno solo.', 5, 2, 18);

-- I Videogiochi
INSERT INTO Frase(Stringa, Posizione, IdPagina, IdUtente) VALUES ('Il termine generalmente tende a identificare un software, ma in alcuni casi può riferirsi anche a un dispositivo hardware dedicato a uno specifico gioco.', 2, 3, 20);

--Alessandro Manzoni
INSERT INTO Frase(Stringa, Posizione, IdPagina, IdUtente, IdLink) VALUES ('Considerato uno dei maggiori romanzieri italiani di tutti i tempi per il suo celebre romanzo I promessi sposi, caposaldo della letteratura italiana, Manzoni ebbe il merito principale di aver gettato le basi per il romanzo moderno e di aver così patrocinato l''unità linguistica italiana, sulla scia di quella letteratura moralmente e civilmente impegnata propria dell''Illuminismo italiano.', 2, 4, 3, 6);
INSERT INTO Frase(Stringa, Posizione, IdPagina, IdUtente) VALUES ('Passato dalla temperie neoclassica a quella romantica, il Manzoni, divenuto fervente cattolico dalle tendenze liberali, lasciò un segno indelebile anche nella storia del teatro italiano (per aver rotto le tre unità aristoteliche) e in quella poetica.', 3, 4, 13);
INSERT INTO Frase(Stringa, Posizione, IdPagina, IdUtente) VALUES ('Il successo e i numerosi riconoscimenti pubblici e accademici (fu senatore del Regno d''Italia) si affiancarono a una serie di problemi di salute (nevrosi, agorafobia) e famigliari (i numerosi lutti che afflissero la vita domestica dello scrittore) che lo ridussero in un progressivo isolamento esistenziale.', 4, 4, 19);

--Apple
INSERT INTO Frase(Stringa, Posizione, IdPagina, IdUtente, IdLink) VALUES ('Apple Inc (chiamata in precedenza Apple Computer e nota come Apple) è un''azienda multinazionale statunitense che produce sistemi operativi, smartphone, computer e dispositivi multimediali, con sede a Cupertino, in California. È considerata una delle società tecnologiche Big Tech, assieme ad Amazon, Google, Microsoft e Meta.', 1, 5, 5, 7);

--I Promessi Sposi
INSERT INTO Frase(Stringa, Posizione, IdPagina, IdUtente) VALUES ('Preceduto dal Fermo e Lucia, spesso considerato romanzo a sé, fu pubblicato in una prima versione tra il 1825 e il 1827 (detta "ventisettana"); rivisto in seguito dallo stesso autore, soprattutto nel linguaggio, fu ripubblicato nella versione definitiva tra il 1840 e il 1842 (detta "quarantana").', 2, 6, 14);

--Microsoft
INSERT INTO Frase(Stringa, Posizione, IdPagina, IdUtente) VALUES ('Microsoft Corporation (in precedenza Micro-Soft Company, comunemente Microsoft) è un''azienda multinazionale statunitense d''informatica con sede a Redmond nello Stato di Washington (Stati Uniti)', 1, 7, 4);
INSERT INTO Frase(Stringa, Posizione, IdPagina, IdUtente) VALUES ('Microsoft è una delle più importanti al mondo nel settore.', 3, 7, 19);
