-- Utiliser SHOW ERROR; pour repérer les erreurs

-- 1 Ecrire la fonction FinValidite qui calcule la date de fin de validité de l’adhésion d’un membre dont le numéro est passé en paramètre.

CREATE OR REPLACE FUNCTION FinValidite(v_numero_membre IN INTEGER) RETURN DATE IS  		
	date_fin_validite DATE;
BEGIN  
	SELECT ADD_MONTHS(date_adhere, duree) INTO date_fin_validite
	FROM Membre	
	WHERE numero_membre = v_numero_membre;
	Return date_fin_validite;  
END;

-- 2 Ecrire la fonction AdhesionAjour qui retourne une valeur booléenne afin de savoir si un membre peut ou non effectuer des locations.

CREATE OR REPLACE FUNCTION AdhesionAJour(v_numero_membre IN INTEGER) RETURN BOOLEAN IS  
	v_location BOOLEAN;
	v_date_fin_validite DATE := FinValidite(v_numero_membre); 
BEGIN  
	v_location := (v_date_fin_validite >= SYSDATE);
	Return v_location;  
END; 

-- 3 Ecrire la procédure RetourExemplaire qui accepte en paramètres un numéro d’ISBN et un numéro d’exemplaire afin d’enregistrer la restitution de l’exemplaire de l’ouvrage emprunté.

CREATE OR REPLACE PROCEDURE RetourExemplaire(v_isbn IN NUMBER, v_exemplaire IN NUMBER) AS
BEGIN	
	UPDATE Details SET date_de_rendu = SYSDATE
	WHERE date_de_rendu IS NULL AND isbn = v_isbn AND numero_exemplaire = v_exemplaire;
END;

-- 4 Ecrire la procédure PurgeMembres qui permet de supprimer tous les membres dont l’adhésion n’a pas été renouvelée depuis trois ans.

CREATE OR REPLACE PROCEDURE PurgeMembres AS
BEGIN
	DELETE FROM Membre 
	WHERE (TRUNC(SYSDATE(), 'YYYY') - TRUNC(ADD_MONTHS(date_adhere, duree), 'YYYY')) > 3;
END;

-- 5 Ecrire la fonction MesureActivite qui permet de connaître le numéro du membre qui a emprunté le plus d’ouvrage pendant une période de temps passée en paramètre de la fonction. Cette période est exprimée en mois.

CREATE OR REPLACE FUNCTION MesureActivite(v_duree IN INTEGER) RETURN INTEGER IS
	v_numero_membre INTEGER;
BEGIN
	SELECT count(*) INTO v_numero_membre FROM Emprunt 
	WHERE MONTHS_BETWEEN(SYSDATE, date_emprunt) < v_duree AND rownum = 1 
	GROUP BY (numero_membre) 
	ORDER BY count(*) DESC;
	Return v_numero_membre;
END;

-- 6 Ecrie la fonction EmpruntMoyen qui accepte en paramètre d’entrée le numéro d’un membre et qui retourne la durée moyenne (en nombre de jours) d’emprunt d’un ouvrage.

CREATE OR REPLACE FUNCTION EmpruntMoyen(v_numero_membre IN INTEGER) RETURN INTEGER IS
	v_duree_moyenne INTEGER;
BEGIN
	SELECT TRUNC(AVG(TRUNC(date_de_rendu, 'DD') - TRUNC(date_emprunt, 'DD')+1), 2) INTO v_duree_moyenne FROM Emprunt E, Details D
	WHERE E.numero_membre = v_numero_membre AND D.numero_emprunt = E.numero_emprunt AND D.date_de_rendu IS NOT NULL;
	Return v_duree_moyenne;
END;

/* 7 Ecrire la fonction DureeMoyenne qui accepte en paramètre un numéro d’ISBN et
éventuellement un numéro d’exemplaire et qui retourne, soit la durée moyenne d’emprunt de
l’ouvrage (seul le numéro ISBN est connu), soit la durée moyenne d’emprunt de l’exemplaire
dans le cas où l’on connaît le numéro d’ISBN et le numéro de l’exemplaire. */

CREATE OR REPLACE FUNCTION DureeMoyenne(v_isbn IN NUMBER, v_exemplaire IN NUMBER DEFAULT NULL) RETURN NUMBER IS
	v_duree NUMBER;	
BEGIN
	IF(v_exemplaire IS NULL) THEN
		SELECT AVG(TRUNC(date_de_rendu, 'DD') - TRUNC(date_emprunt, 'DD')+1) INTO v_duree
		FROM Emprunt E, Details D
		WHERE E.numero_emprunt = D.numero_emprunt AND D.isbn = v_isbn AND date_de_rendu IS NOT NULL;
	ElSE
		SELECT AVG(TRUNC(date_de_rendu, 'DD') - TRUNC(date_emprunt, 'DD')+1) INTO v_duree
		FROM Emprunt E, Details D
		WHERE E.numero_emprunt = D.numero_emprunt AND D.isbn = v_isbn AND D.numero_exemplaire = v_exemplaire AND date_de_rendu IS NOT NULL;
	END IF;
	Return v_duree;
END;

/* 8 Ecrire la procédure MajEtatExemplaire pour mettre à jour l’état des exemplaires et
planifier l’exécution de cette procédure toutes les deux semaines.*/

CREATE OR REPLACE PROCEDURE MajEtatExemplaire IS
	v_nombre_emprunts NUMBER;
BEGIN
	SELECT count(*) INTO v_nombre_emprunts FROM Details D, Exemplaire E
	WHERE D.isbn = E.isbn and D.numero_exemplaire = E.numero_exemplaire 
	GROUP BY (E.isbn, E.numero_exemplaire);
	UPDATE Exemplaire SET etat = 'Neuf' WHERE v_nombre_emprunts <= 10;
	UPDATE Exemplaire SET etat = 'Bon' WHERE v_nombre_emprunts BETWEEN 11 AND 25;
	UPDATE Exemplaire SET etat = 'Moyen' WHERE v_nombre_emprunts BETWEEN 26 AND 40;
	UPDATE Exemplaire SET etat = 'Douteux' WHERE v_nombre_emprunts BETWEEN 41 AND 60;
	UPDATE Exemplaire SET etat = 'Mauvais' WHERE v_nombre_emprunts >= 61;
	COMMIT;
END;

-- Ne marche que si l'on possède les privilèges
BEGIN
	DBMS_SCHEDULER.CREATE_JOB('CalculEtatExemplaire', 'MajEtatExemplaire', systimestamp, 'systimestamp + 14');
END;

/* 9 Au cours des questions précédentes, la séquence Seq_Membre a été définie et est utilisée
pour l’ajout d’informations dans la table des membres. Pour faciliter le travail avec cette
séquence, il est judicieux de créer la fonction AjouteMembre, qui accepte en paramètre les
différentes valeurs de chacune des colonnes et qui retourne le numéro de séquence attribué à
la ligne d’information nouvellement ajoutée dans la table. */

CREATE OR REPLACE FUNCTION AjouteMembre (v_nom IN VARCHAR2, v_prenom IN VARCHAR2, v_adresse IN VARCHAR2, v_portable IN VARCHAR2, v_adhesion IN DATE, v_duree IN NUMBER) RETURN NUMBER AS
	v_numero_membre NUMBER;
BEGIN
	INSERT INTO Membre (numero_membre, nom, prenom, adresse, telephone_portable, date_adhere, duree)
	VALUES (seq_numero_membre.NEXTVAL, v_nom, v_prenom, v_adresse, v_portable, v_adhesion, v_duree)
	RETURNING numero_membre INTO v_numero_membre;
	Return v_numero_membre;
END;

/* 10 Ecrire la procédure SupprimeExemplaire qui accepte en paramètre l’identification
complète d’un exemplaire (ISBN et numéro d’exemplaire) et supprime celui-ci s’il n’est pas
emprunté.*/

CREATE OR REPLACE PROCEDURE SupprimeExemplaire (v_isbn IN NUMBER, v_exemplaire IN NUMBER) AS
BEGIN
	DELETE FROM Exemplaire
	WHERE isbn = v_isbn AND numero_exemplaire = v_exemplaire;
	IF (SQL%ROWCOUNT = 0) THEN
		RAISE NO_DATA_FOUND;
	END IF;
EXCEPTION
	WHEN NO_DATA_FOUND THEN
		raise_application_error(-20010, 'Exemplaire inconnu');
END;

/* 11 Le plus souvent, les membres n’empruntent qu’un seul ouvrage. Ecrire la procédure
EmpruntExpress qui accepte en paramètre le numéro du membre et l’identification exacte de
l’exemplaire emprunté (ISBN et numéro). La procédure ajoute automatiquement une ligne
dans la table des emprunts et une ligne dans la table des détails.*/

--Déterminer le numero_emprunt du dernier emprunt créé
SELECT count(*) FROM Emprunt;

--On débute la séquence avec ce numero d'emprunt
CREATE SEQUENCE seq_emprunt START WITH 20;

CREATE OR REPLACE PROCEDURE EmpruntExpress(v_numero_membre IN NUMBER, v_isbn IN NUMBER, v_exemplaire IN NUMBER) AS
	v_emprunt emprunt.numero_emprunt%type;
BEGIN
	INSERT INTO Emprunt (numero_emprunt, numero_membre, date_emprunt)
	VALUES(seq_emprunt.NEXTVAL, v_numero_membre, SYSDATE) RETURNING numero_emprunt INTO v_emprunt;
	INSERT INTO Details (numero_emprunt, numero_detail, isbn, numero_exemplaire)
	VALUES(v_emprunt, 1, v_isbn, v_exemplaire);
END;

/* Regrouper l’ensemble des procédures et des fonctions définies au sein du package Livre.*/
-- Entete

CREATE OR REPLACE PACKAGE Livre AS
	FUNCTION FinValidite (v_numero_membre IN INTEGER) Return DATE;
	FUNCTION AdhesionAJour (v_numero IN INTEGER) Return boolean;
	PROCEDURE RetourExemplaire (v_isbn IN NUMBER, v_numero IN NUMBER);
	PROCEDURE PurgeMembre; 
	FUNCTION MesureActivite (v_duree IN INTEGER) Return INTEGER;
	FUNCTION EmpruntMoyen (v_membre IN INTEGER) Return INTEGER;
	FUNCTION DureeMoyenne (v_isbn IN NUMBER, v_exemplaire IN NUMBER DEFAULT NULL) Return INTEGER;
	PROCEDURE MajEtatExemplaire;	
	FUNCTION AjouteMembre (v_nom IN VARCHAR2, v_prenom IN VARCHAR2, v_portable IN VARCHAR2, v_date_adhere in DATE, v_duree IN NUMBER) Return NUMBER;
	PROCEDURE SupprimeExemplaire (v_isbn IN NUMBER, v_numero IN NUMBER);
	PROCEDURE EmpruntExpress (v_membre IN NUMBER, v_isbn IN NUMBER, v_exemplaire IN NUMBER);
END Livre;

--Erreur sous Oracle : Echec de la résolution des détails de l'objet
--Corps : copier collé de toutes les fonctions et procedure ci dessus
CREATE OR REPLACE PACKAGE BODY Libre AS
	----------------------------------------------------------------------------------
	CREATE OR REPLACE FUNCTION FinValidite(v_numero_membre IN INTEGER) RETURN DATE IS  		date_fin_validite DATE;
	BEGIN  
		SELECT ADD_MONTHS(date_adhere, duree) INTO date_fin_validite
		FROM Membre	
		WHERE numero_membre = v_numero_membre;
		Return date_fin_validite;  
	END;
	----------------------------------------------------------------------------------
	CREATE OR REPLACE FUNCTION AdhesionAJour(v_numero_membre IN INTEGER) RETURN BOOLEAN IS  
		v_location BOOLEAN;
		v_date_fin_validite DATE := FinValidite(v_numero_membre); 
	BEGIN  
		v_location := (v_date_fin_validite >= SYSDATE);
		Return v_location;  
	----------------------------------------------------------------------------------
	CREATE OR REPLACE PROCEDURE RetourExemplaire(v_isbn IN NUMBER, v_exemplaire IN NUMBER) AS
	BEGIN	
		UPDATE Details SET date_de_rendu = SYSDATE
		WHERE date_de_rendu IS NULL AND isbn = v_isbn AND numero_exemplaire = v_exemplaire;
	END;
	----------------------------------------------------------------------------------
	CREATE OR REPLACE PROCEDURE PurgeMembres AS
	BEGIN
		DELETE FROM Membre 
		WHERE (TRUNC(SYSDATE(), 'YYYY') - TRUNC(ADD_MONTHS(date_adhere, duree), 'YYYY')) > 3;
	END;
	----------------------------------------------------------------------------------
	CREATE OR REPLACE FUNCTION MesureActivite(v_duree IN INTEGER) RETURN INTEGER IS
		v_numero_membre INTEGER;
	BEGIN
		SELECT count(*) INTO v_numero_membre FROM Emprunt 
		WHERE MONTHS_BETWEEN(SYSDATE, date_emprunt) < v_duree AND rownum = 1 
		GROUP BY (numero_membre) 
		ORDER BY count(*) DESC;
		Return v_numero_membre;
	END;
	----------------------------------------------------------------------------------
	CREATE OR REPLACE FUNCTION EmpruntMoyen(v_numero_membre IN INTEGER) RETURN INTEGER IS
		v_duree_moyenne INTEGER;
	BEGIN
		SELECT TRUNC(AVG(TRUNC(date_de_rendu, 'DD') - TRUNC(date_emprunt, 'DD')+1), 2) INTO v_duree_moyenne FROM Emprunt E, Details D
		WHERE E.numero_membre = v_numero_membre AND D.numero_emprunt = E.numero_emprunt AND D.date_de_rendu IS NOT NULL;
		Return v_duree_moyenne;
	END;
	----------------------------------------------------------------------------------
	CREATE OR REPLACE FUNCTION DureeMoyenne(v_isbn IN NUMBER, v_exemplaire IN NUMBER DEFAULT NULL) RETURN NUMBER IS
		v_duree NUMBER;	
	BEGIN
		IF(v_exemplaire IS NULL) THEN
			SELECT AVG(TRUNC(date_de_rendu, 'DD') - TRUNC(date_emprunt, 'DD')+1) INTO v_duree
			FROM Emprunt E, Details D
			WHERE E.numero_emprunt = D.numero_emprunt AND D.isbn = v_isbn AND date_de_rendu IS NOT NULL;
		ElSE
			SELECT AVG(TRUNC(date_de_rendu, 'DD') - TRUNC(date_emprunt, 'DD')+1) INTO v_duree
			FROM Emprunt E, Details D
			WHERE E.numero_emprunt = D.numero_emprunt AND D.isbn = v_isbn AND D.numero_exemplaire = v_exemplaire AND date_de_rendu IS NOT NULL;
		END IF;
		Return v_duree;
	END;
	----------------------------------------------------------------------------------
	CREATE OR REPLACE PROCEDURE MajEtatExemplaire IS
		v_nombre_emprunts NUMBER;
	BEGIN
		SELECT count(*) INTO v_nombre_emprunts FROM Details D, Exemplaire E
		WHERE D.isbn = E.isbn and D.numero_exemplaire = E.numero_exemplaire 
		GROUP BY (E.isbn, E.numero_exemplaire);
		UPDATE Exemplaire SET etat = 'Neuf' WHERE v_nombre_emprunts <= 10;
		UPDATE Exemplaire SET etat = 'Bon' WHERE v_nombre_emprunts BETWEEN 11 AND 25;
		UPDATE Exemplaire SET etat = 'Moyen' WHERE v_nombre_emprunts BETWEEN 26 AND 40;
		UPDATE Exemplaire SET etat = 'Douteux' WHERE v_nombre_emprunts BETWEEN 41 AND 60;
		UPDATE Exemplaire SET etat = 'Mauvais' WHERE v_nombre_emprunts >= 61;
		COMMIT;
	END;
	----------------------------------------------------------------------------------
	CREATE OR REPLACE FUNCTION AjouteMembre (v_nom IN VARCHAR2, v_prenom IN VARCHAR2, v_adresse IN VARCHAR2, v_portable IN VARCHAR2, v_adhesion IN DATE, v_duree IN NUMBER) RETURN NUMBER AS
		v_numero_membre NUMBER;
	BEGIN
		INSERT INTO Membre (numero_membre, nom, prenom, adresse, telephone_portable, date_adhere, duree)
		VALUES (seq_numero_membre.NEXTVAL, v_nom, v_prenom, v_adresse, v_portable, v_adhesion, v_duree)
		RETURNING numero_membre INTO v_numero_membre;
		Return v_numero_membre;
	END;
	----------------------------------------------------------------------------------
	CREATE OR REPLACE PROCEDURE SupprimeExemplaire (v_isbn IN NUMBER, v_exemplaire IN NUMBER) AS
	BEGIN
		DELETE FROM Exemplaire
		WHERE isbn = v_isbn AND numero_exemplaire = v_exemplaire;
		IF (SQL%ROWCOUNT = 0) THEN
			RAISE NO_DATA_FOUND;
		END IF;
	EXCEPTION
		WHEN NO_DATA_FOUND THEN
			raise_application_error(-20010, 'Exemplaire inconnu');
	END;
	----------------------------------------------------------------------------------
	CREATE OR REPLACE PROCEDURE EmpruntExpress(v_numero_membre IN NUMBER, v_isbn IN NUMBER, v_exemplaire IN NUMBER) AS
		v_emprunt emprunt.numero_emprunt%type;
	BEGIN
		INSERT INTO Emprunt (numero_emprunt, numero_membre, date_emprunt)
		VALUES(seq_emprunt.NEXTVAL, v_numero_membre, SYSDATE) RETURNING numero_emprunt INTO v_emprunt;
		INSERT INTO Details (numero_emprunt, numero_detail, isbn, numero_exemplaire)
		VALUES(v_emprunt, 1, v_isbn, v_exemplaire);
	END;
	----------------------------------------------------------------------------------
END Livre;

