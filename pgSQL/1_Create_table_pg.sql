DROP SCHEMA public CASCADE;
CREATE SCHEMA public;

-- ***************************************************************************************************

CREATE TABLE Genre(
    code_genre      VARCHAR(5) NOT NULL,
    libelle     VARCHAR(30) NOT NULL,
-- -------------------------------------------------------------------------
    CONSTRAINT pk_genre PRIMARY KEY (code_genre));

-- ***************************************************************************************************

CREATE TABLE Ouvrage(
    isbn            NUMERIC(10,0) NOT NULL,
    titre           VARCHAR(100) NOT NULL,
    auteur          VARCHAR(30) DEFAULT NULL,
    editeur         VARCHAR(30) DEFAULT NULL,
    code_genre      VARCHAR(5) DEFAULT NULL,
-- -------------------------------------------------------------------------
    CONSTRAINT pk_ouvrage PRIMARY KEY (isbn),
    CONSTRAINT fk_ouvrage_genre FOREIGN KEY (code_genre) REFERENCES Genre(code_genre) ON DELETE CASCADE);

-- ***************************************************************************************************

CREATE TABLE Exemplaire(
    isbn            NUMERIC(10,0) NOT NULL,
    numero_exemplaire   INTEGER NOT NULL,
    etat        VARCHAR(10) NOT NULL,
-- -------------------------------------------------------------------------
    CONSTRAINT pk_exemplaire PRIMARY KEY (isbn, numero_exemplaire),
    CONSTRAINT fk_exemplaire_ouvrage FOREIGN KEY (isbn) REFERENCES Ouvrage(isbn) ON DELETE CASCADE,
    CONSTRAINT cc_exemplaire_etat CHECK( etat IN ('Neuf', 'Bon', 'Moyen', 'Mauvais')));

-- ***************************************************************************************************

CREATE TABLE Membre(
    numero_membre       INTEGER NOT NULL,
    nom             VARCHAR(10) NOT NULL,
    prenom          VARCHAR(10) NOT NULL,
    adresse         VARCHAR(30) NOT NULL,
    telephone       VARCHAR(10) NOT NULL,
    date_adhere     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    duree           INTEGER NOT NULL,
-- -------------------------------------------------------------------------
    CONSTRAINT pk_membre PRIMARY KEY(numero_membre),
    CONSTRAINT cc_membre_duree CHECK( duree IN (1, 3, 6, 12)));

-- ***************************************************************************************************

CREATE TABLE Emprunt(
    numero_emprunt  INTEGER NOT NULL,
    numero_membre   INTEGER NOT NULL,
    date_emprunt    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
-- -------------------------------------------------------------------------
    CONSTRAINT pk_emprunt PRIMARY KEY (numero_emprunt),
    CONSTRAINT fk_emprunt_membre FOREIGN KEY (numero_membre) REFERENCES Membre(numero_membre) ON DELETE CASCADE);

-- ***************************************************************************************************

CREATE TABLE Details_Emprunt(
    numero_emprunt  INTEGER NOT NULL,
    numero_detail   INTEGER NOT NULL,
    isbn        NUMERIC(10,0) NOT NULL,
    numero_exemplaire      INTEGER NOT NULL,
    date_de_rendu   DATE DEFAULT NULL,
-- -------------------------------------------------------------------------
    CONSTRAINT pk_details PRIMARY KEY (numero_emprunt, numero_detail),
    CONSTRAINT fk_details_emprunt FOREIGN KEY (numero_emprunt) REFERENCES Emprunt(numero_emprunt) ON DELETE CASCADE,
    CONSTRAINT fk_detail_exemplaire FOREIGN KEY (isbn, numero_exemplaire) REFERENCES Exemplaire(isbn, numero_exemplaire) ON DELETE CASCADE);

-- ***************************************************************************************************
