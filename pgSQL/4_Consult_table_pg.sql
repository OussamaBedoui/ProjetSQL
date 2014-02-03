/* 4) Extraction simple d’informations
Consultez le contenu de chaque table à l’aide d’une requête d’extraction simple qui permet de visualiser toutes les lignes et toutes les colonnes de chaque table.*/

SELECT * FROM Genre;
SELECT * FROM Ouvrage;
SELECT * FROM Exemplaire;
SELECT * FROM Membre;
SELECT * FROM Emprunt;
SELECT * FROM Details;

/* 5) Activation de l’historique des mouvements
Les manipulations de la table des membres sont sensibles. Activez l’historique des mouvements sur cette table. Effectuez la même opération sur la table « DETAILS » */
/*
CREATE TABLE Temp_Membre(
    id_affichage NUMBER(2),
    affichage VARCHAR2(50));

CREATE TABLE Temp_Details(
    id_affichage NUMBER(2),
    affichage VARCHAR2(50));

CREATE SEQUENCE compteur START WITH 1 INCREMENT BY 1;
*/
/*
CREATE TABLE Temp_Membre(
    id_affichage NUMERIC(2),
    affichage VARCHAR(50));

CREATE TABLE Temp_Details(
    id_affichage NUMERIC(2),
    affichage VARCHAR(50));

CREATE SEQUENCE v_compteur START WITH 1 INCREMENT BY 1;

CREATE OR REPLACE PACKAGE TriggerMoment
    AS v_compteur NUMBER:=0;
END TriggerMoment

CREATE OR REPLACE TRIGGER BeforeInstructionOnMember
    BEFORE UPDATE ON MEMBRE
    BEGIN
        INSERT INTO Temp_AFFICHAGE VALUES(
        v_compteur.NEXTVAL,
        ‘BEFORE niveau instruction : compteur =’ || TriggerMoment.v_compteur );
        TriggerMoment.v_compteur := TriggerMoment.v_compteur + 1;
    END BeforeInstructionOnMember;

CREATE OR REPLACE TRIGGER AfterInstructionOnMember
    AFTER UPDATE ON MEMBRE
    BEGIN
        INSERT INTO Temp_AFFICHAGE VALUES(
        v_compteur.NEXTVAL,
        ‘AFTER niveau instruction : compteur =’ || TriggerMoment.v_compteur );
        TriggerMoment.v_compteur := TriggerMoment.v_compteur + 1;
    END BeforeInstructionOnMember;

CREATE OR REPLACE TRIGGER BeforeInstructionOnDetails
    BEFORE UPDATE ON DETAILS
    BEGIN
        INSERT INTO Temp_AFFICHAGE VALUES(
        v_compteur.NEXTVAL,
        ‘BEFORE niveau instruction : compteur =’ || TriggerMoment.v_compteur );
        TriggerMoment.v_compteur := TriggerMoment.v_compteur + 1;
    END AfterInstructionOnDetails;

CREATE OR REPLACE TRIGGER AfterInstructionOnDetails
    AFTER UPDATE ON DETAILS
    BEGIN
        INSERT INTO Temp_AFFICHAGE VALUES(
        v_compteur.NEXTVAL,
        ‘AFTER niveau instruction : compteur =’ || TriggerMoment.v_compteur );
        TriggerMoment.v_compteur := TriggerMoment.v_compteur + 1;
    END AfterInstructionOnDetails;
*/
/* 6) Ajout d’une colonne :
Pour faciliter la gestion des emprunts et identifier plus rapidement les fiches pour lesquelles l’ensemble des exemplaires n’est pas restitué, il a été décidé d’ajouter une colonne «ETAT »qui peut prendre les valeurs (EC : en cours) par défaut et (RE : rendue) lorsque l’ensemble des exemplaires est rendu. Ecrivez l’instruction SQL qui permet d’effectuer la modification de structure souhaitée. Mettez à jour l’état de chaque fiche de location en le faisant passer à RE (rendue) si tous les ouvrages empruntés par le membre ont été restitués à la bibliothèque. */

-- Ajout d'une colone nb_emprunt dans la table Exemplaire afin de comptabiliser le nombre d'emprunt de chaque livre

ALTER TABLE Emprunt ADD etat VARCHAR(2) DEFAULT 'RE';
ALTER TABLE Emprunt ADD CONSTRAINT cc_emprunt_etat CHECK(etat IN('RE', 'EC'));

-- Definition de l'état initial.
UPDATE Emprunt SET etat = 'EC' WHERE numero_emprunt = (SELECT DISTINCT numero_emprunt FROM emprunt NATURAL JOIN details WHERE date_de_rendu IS NULL);


/*DECLARE
    CURSOR c_details IS SELECT etat FROM Details;
    v_date_de_rendu details.date_de_rendu%TYPE;
    v_numero_emprunt details.numero_emprunt%TYPE;
    BEGIN
        OPEN c_details;
        LOOP
            FETCH c_details INTO v_date_de_rendu;
            FETCH c_details INTO v_numero_emprunt;
            EXIT WHEN c_details%NOTFOUND or c_details%ROWCOUNT >15;
            IF v_date_de_rendu IS NULL THEN
                UPDATE Emprunt SET etat = 'EC' WHERE Emprunt.numero_emprunt = v_numero_emprunt;
            ELSE
				UPDATE Emprunt SET etat = 'RE' WHERE Emprunt.numero_emprunt = v_numero_emprunt;
            END IF;
        END LOOP;
    CLOSE c_details;
END;*/

/*
CURSOR c_emprunt IS SELECT * FROM Emprunt;
CURSOR c_details IS SELECT * FROM Details;
    SELECT etat,
    FROM Emprunt, Details
    FOR UPDATE OF etat
    v_emprunt c_emprunt%ROWTYPE;
    v_details c_details%ROWTYPE;
    BEGIN
        OPEN c_emprunt;
        OPEN c_details;
        FETCH c_emprunt INTO v_emprunt;
        UPDATE Emprunt SET etat = 'EC'
        WHERE c_details.numero_emprunt = c_emprunt.numero_emprunt AND (c_details.date_de_rendu IS NULL);
        UPDATE Emprunt SET etat = 'RE'
        WHERE c_details.numero_emprunt = c_emprunt.numero_emprunt AND (c_details.date_de_rendu IS NOT NULL);
        COMMIT
        CLOSE c_emprunt;        
        CLOSE c_details;
    END;
*/


/* 7) Mise à jour conditionnelle
On souhaite modifier l’état des exemplaires en fonction de leur nombre de locations afin de faire passer les exemplaires actuellement à l’état Neuf vers l’état Bon et supprimer les exemplaires qui ont été loués plus de 60 fois. En effet, les bibliothécaires considèrent qu’un tel exemplaire doit être retiré de la location car il ne répond pas à la qualité souhaitée par les membres. Les livres sont considérés neufs lorsqu’ils ont été empruntés moins de 11 fois. A partir du 11ème emprunt et jusqu’au 25ème leur état est bon. */

-- Ajout d'une colone nb_emprunt dans la table Exemplaire afin de comptabiliser le nombre d'emprunt de chaque livre

ALTER TABLE Exemplaire ADD COLUMN nb_emprunt INTEGER DEFAULT 0;


-- Definition de l'état initial du nombre d'emprunt en se basant sur l'état des livres
-- Neuf = 0 fois / Bon = 11 fois / Moyen = 25 fois / Mauvais = 60 fois

UPDATE Exemplaire SET nb_emprunt = 11 WHERE etat ~* 'Bon';
UPDATE Exemplaire SET nb_emprunt = 25 WHERE etat ~* 'Moyen';
UPDATE Exemplaire SET nb_emprunt = 60 WHERE etat ~* 'Mauvais';


/*LA SUITE EST A FAIRE DIRECTEMENT EN ORACLE

DECLARE
CURSOR c_exemplaire IS
    SELECT nb_emprunt, etat
    FROM Exemplaire
    FOR UPDATE OF nb_emprunt ;

v_exemplaire  c_exemplaire%ROWTYPE;

BEGIN
    OPEN c_exemplaire;
    FETCH c_exemplaire INTO v_exemplaire;
        CASE
        UPDATE Exemplaire SET etat = 'Bon'
        WHERE COUNT(*) >= 11;
    COMMIT;
    CLOSE c_employe ;
END;

BEGIN
    OPEN c_exemplaire;
    FETCH c_exemplaire INTO v_exemplaire;
        CASE
        UPDATE Exemplaire SET etat = 'Moyen'
        WHERE COUNT(*) >= 25;
    COMMIT;
    CLOSE c_employe ;
END;

BEGIN
    OPEN c_exemplaire;
    FETCH c_exemplaire INTO v_exemplaire;
        CASE
        DELETE FROM Exemplaire
        WHERE COUNT(*) >= 60;
    COMMIT;
    CLOSE c_employe ;
END;
*/

/* 8) Supprimez tous les exemplaires dont l’état est mauvais.*/

DELETE FROM Exemplaire WHERE etat ~* 'Mauvais';

DELETE FROM Exemplaire WHERE etat = 'Mauvais';

/* 9) Etablissez la liste des ouvrages que possède la bibliothèque.*/

SELECT isbn, titre FROM Ouvrage;

/* 10) Etablissez la liste des membres qui ont emprunté un ouvrage depuis plus de deux semaines en indiquant le nom de l’ouvrage.*/

-- Uniquement pour les membres qui n'ont pas encore rendus depuis plus de 2 semaines

SELECT numero_membre, nom, prenom, titre, date_emprunt
FROM Membre
	JOIN Emprunt USING (numero_membre)
	JOIN Details USING (numero_emprunt)
	JOIN Ouvrage USING (isbn)
WHERE date_de_rendu IS NULL AND date_emprunt <= CURRENT_TIMESTAMP - INTERVAL '2 week';

/* 11) Etablissez le nombre d’ouvrages dont on dispose par catégorie.*/

SELECT code_genre, libelle, COUNT (*) AS nombre_ouvrages
FROM Ouvrage JOIN Genre USING (code_genre)
GROUP BY code_genre, libelle
ORDER BY nombre_ouvrages;

/* 12) Etablissez la durée moyenne d’emprunt d’un livre par un membre.*/

-- Avec utilisation de sous requêtes
SELECT temp.numero_membre, nom, prenom, temp.durée_emprunt_moyenne 
FROM Membre NATURAL JOIN (
	SELECT numero_membre, AVG(details.date_de_rendu - emprunt.date_emprunt) 
		AS durée_emprunt_moyenne 
	FROM Emprunt NATURAL JOIN Details 
	GROUP BY numero_membre)
		AS temp;

-- Avec double jointure et mise en forme de la sortie du SELECT

SELECT	nom ||' '|| prenom ||' (n°'|| numero_membre ||')' AS Membre,
	EXTRACT ('day' FROM AVG(date_de_rendu - date_emprunt)) ||' Jour(s)' AS durée_moyenne_emprunt  
FROM Membre 
	JOIN Emprunt USING (numero_membre)
	JOIN Details USING (numero_emprunt)
GROUP BY numero_membre, nom, prenom
ORDER BY nom; 

/* 13) Calculez la durée moyenne de l’emprunt en fonction du genre du livre.*/

-- Ajout du libellé de chaque genre (ajout d'une sous requete supplémentaire).
SELECT code_genre, libelle, duree_moyenne
FROM Genre NATURAL JOIN (
	SELECT code_genre, AVG(duree) AS duree_moyenne
	FROM Ouvrage NATURAL JOIN (
		SELECT isbn, (details.date_de_rendu - emprunt.date_emprunt) AS duree
		FROM Emprunt NATURAL JOIN Details
		)AS t1
	GROUP BY code_genre
	) AS t2;

-- Avec triple jointure
SELECT code_genre, libelle, AVG(details.date_de_rendu - emprunt.date_emprunt) AS duree_moyenne_emprunt
FROM Ouvrage 
	JOIN Details USING (isbn)
	JOIN Emprunt USING (numero_emprunt)
	JOIN Genre USING (code_genre)
GROUP BY code_genre, libelle;


/* 14) Etablissez la liste des ouvrages loués plus de 10 fois au cours des 12 derniers mois.*/

SELECT isbn, titre, COUNT (*)
FROM Details
	JOIN Emprunt USING (numero_emprunt)
	JOIN Ouvrage USING (isbn)
WHERE date_emprunt > CURRENT_TIMESTAMP - INTERVAL '12 month'
GROUP BY isbn, titre
HAVING COUNT(*) >= 10;

/* 15) Etablissez la liste de tous les ouvrages avec à côté de chacun d’eux les numéros d’exemplaires qui existent dans la base.*/

SELECT titre, COUNT(*) AS quantité_exemplaire
FROM Ouvrage LEFT JOIN Exemplaire USING (isbn) 
GROUP BY titre;


/* 16) Définissez une vue qui permet de connaître pour chaque membre, le nombre d’ouvrages empruntés, et donc non encore rendu.*/

CREATE VIEW nb_ouvrages_empruntes AS 
	SELECT numero_membre, COUNT (*) FROM Emprunt E, Details D
	WHERE E.numero_emprunt = D.numero_emprunt
	GROUP BY numero_membre;

/* 17) Définissez une vue qui permet de connaître le nombre d’emprunts par ouvrage.*/

CREATE VIEW nb_emprunts_par_ouvrage AS 
	SELECT isbn, COUNT (*) FROM Details
	GROUP BY isbn;

/* 18) Etablissez la liste des membres triés par ordre alphabétique.*/

SELECT nom, prenom, numero_membre FROM Membre ORDER BY nom;


/* 19) On souhaite obtenir le nombre de locations par titre et le nombre de locations de chaque exemplaire. Pour obtenir un tel résultat, il est préférable d’utiliser une table temporaire globale et de la remplir au fur et à mesure. Utilisez la clause ON COMMIT PRESERVE ROWS lors de la création de la table temporaire globale.*/

CREATE GLOBAL TEMPORARY TABLE location_exemplaires_titres (
	numero_emprunt INTEGER NOT NULL,
	isbn NUMERIC(10,0),
	exemplaire INTEGER NOT NULL)
ON COMMIT PRESERVE ROWS;

-- remplissage ?


/* 20) Affichez la liste des genres et pour chaque genre, la liste des ouvrages qui lui appartiennent.*/

SELECT DISTINCT libelle, titre FROM Genre G, Ouvrage O
	WHERE G.code_genre = O.code_genre
	GROUP BY libelle, titre;




