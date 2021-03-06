/* 1 Mettre à jour un déclencheur de base de données afin de vous assurer que lors de la
suppression du dernier exemplaire d’un ouvrage, les informations relatives à l’ouvrage sont
également supprimées. */

CREATE OR REPLACE TRIGGER trg_del_exemplaire
	AFTER DELETE ON Exemplaire
	FOR EACH ROW
DECLARE
	v_nombre_exemplaire INTEGER;
BEGIN
	SELECT count(*) INTO v_nombre_exemplaire FROM Exemplaire WHERE isbn = :old.isbn;
	IF (v_nombre_exemplaire = 1) THEN
		DELETE FROM Ouvrage WHERE isbn = :old.isbn;
	END IF;
END;

/* 2 Définir un déclencheur de base de données permettant de garantir que les emprunts sont
réalisés uniquement par des membres à jour de leur cotisation.*/

CREATE OR REPLACE TRIGGER trg_autorisation
	BEFORE INSERT ON Emprunt
	FOR EACH ROW
DECLARE
	emprunt_bool BOOLEAN;
BEGIN
	emprunt_bool := AdhesionAJour(:old.numero_membre);
	IF NOT emprunt_bool THEN
		RAISE_APPLICATION_ERROR(-20200,'Adhesion non valide');
	END IF;
END;

/* 3 Définir un déclencheur qui interdit le changement de membre pour une fiche de location
déjà enregistrée.*/

CREATE OR REPLACE TRIGGER trg_interdit_chang_emprunt
	BEFORE UPDATE OF numero_membre ON Emprunt
	FOR EACH ROW
BEGIN
	IF(:new.numero_membre != :old.numero_membre) THEN
		RAISE_APPLICATION_ERROR(-20200,'Opération interdite');
	END IF;
END;

/* 4 Définir un déclencheur qui interdit de modifier la référence d’un ouvrage emprunté, il faut
le rendre puis effectuer une nouvelle location */ 
-- C'est quoi la référence ?!

CREATE OR REPLACE TRIGGER trg_intedit_modif_ref
	BEFORE UPDATE OF isbn ON Details
	FOR EACH ROW
BEGIN
	IF(:new.isbn != :old.isbn) THEN
		RAISE_APPLICATION_ERROR(-20200,'Opération interdite');
	END IF;
END;

/* 5 Définir un déclencheur qui met automatiquement à jour l’état d’un exemplaire en fonction
de la valeur enregistrée dans NombreEmprunts. Par exemple, lors de la mise à jour de
valeurs représentant le nombre d’emprunts pour un exemplaire, l’état est mis à jour de façon
automatique. */

CREATE OR REPLACE TRIGGER trg_maj_etat_ex
	BEFORE INSERT OR UPDATE OF nombre_emprunts ON Exemplaire
	FOR EACH ROW
BEGIN
	IF(:new.nombre_emprunts <= 10) THEN
		:new.etat := 'Neuf';
	END IF;
	IF(:new.nombre_emprunts BETWEEN 11 AND 25) THEN
		:new.etat := 'Bon';
	END IF;
	IF(:new.nombre_emprunts BETWEEN 26 AND 40) THEN
		:new.etat := 'Moyen';
	END IF;
	IF(:new.nombre_emprunts BETWEEN 41 AND 60) THEN
		:new.etat := 'Douteux';
	END IF;
	IF(:new.nombre_emprunts >= 61) THEN
		:new.etat := 'Mauvais';
	END IF;
END;

/* 6 Lors de la suppression d’un détail, assurer que l’emprunt a bien été pris en compte au
niveau de l’exemplaire. */

CREATE OR REPLACE TRIGGER trg_suppr_detail
	AFTER DELETE ON Details
	FOR EACH ROW
DECLARE
	v_isbn Details.isbn%type;
	v_exemplaire Details.numero_exemplaire%type;
BEGIN
	SELECT isbn INTO v_isbn FROM Details 
	WHERE isbn = :old.isbn;
	SELECT numero_exemplaire INTO v_exemplaire FROM Details
	WHERE numero_exemplaire = :old.numero_exemplaire;
	UPDATE Exemplaire SET nombre_emprunts = ((SELECT nombre_emprunts FROM Exemplaire WHERE Exemplaire.isbn = v_isbn and Exemplaire.numero_exemplaire = v_exemplaire) + 1) 
	WHERE Exemplaire.isbn = v_isbn and Exemplaire.numero_exemplaire = v_exemplaire;
END;

/* 7 Afin d’améliorer le service rendu aux membres, il est souhaitable de savoir quand
l’emprunt d’un ouvrage a été enregistré et quel employé a effectué l’opération. Le même
genre d’informations doit être disponible pour le retour des exemplaires.
Définir le code nécessaire pour prendre en compte cette nouvelle exigence. Apporter des
modifications de structures si nécessaire. */

DROP TABLE Employe PURGE;
DROP SEQUENCE seq_numero_employe;

CREATE SEQUENCE seq_numero_employe START WITH 1 INCREMENT BY 1;

CREATE TABLE Employe (
	nom VARCHAR2(10) NOT NULL,
	prenom VARCHAR2(10) NOT NULL,
	numero_employe INTEGER NOT NULL,
-----------------------------------------------
	CONSTRAINT pk_employé PRIMARY KEY (numero_employe);
);

ALTER TABLE Emprunt ADD numero_employe INTEGER NOT NULL;
ALTER TABLE Details_Emprunt
    ADD CONSTRAINT fk_numero_employe FOREIGN KEY (numero_employe) REFERENCES Employe(numero_employe);

ALTER TABLE Details ADD numero_employe INTEGER NOT NULL;
ALTER TABLE Details_Emprunt
    ADD CONSTRAINT fk_numero_employe FOREIGN KEY (numero_employe) REFERENCES Employe(numero_employe);

----------------------------------- 2eme version 

ALTER TABLE Emprunt ADD(
	employe VARCHAR2(10),
	date_modif date
);
	
ALTER TABLE Details ADD(
	employe VARCHAR2(10),
	date_modif date
);
	
CREATE OR REPLACE TRIGGER trg_operation_emprunt
	BEFORE INSERT ON Emprunt
	FOR EACH ROW
BEGIN
	:new.employe := user();
	:new.date_modif := sysdate();
END;

CREATE OR REPLACE TRIGGER trg_operation_details
	BEFORE INSERT ON Details
	FOR EACH ROW
BEGIN
	:new.employe := user();
	:new.date_modif := sysdate();
END;

/* 8   Ecrire la fonction AnalyseActivite qui accepte en paramètres le nom d’un utilisateur
Oracle et une date et calcule le nombre d’opérations (emprunts et détails) réalisées par
l’utilisateur, ou bien sur la journée, ou bien pour l’utilisateur sur la journée. La valeur de cette
fonction est toujours un nombre entier.*/

CREATE OR REPLACE FUNCTION AnalyseActivite (v_nom_utilisateur VARCHAR2 DEFAULT NULL, v_date DATE DEFAULT NULL) RETURN INTEGER AS
	v_nombre_operations INTEGER;
BEGIN
	IF(v_nom_utilisateur IS NOT NULL) THEN
		IF(v_date IS NOT NULL) THEN
			SELECT count(*) INTO v_nombre_operations FROM flashback_transaction_query
			WHERE table_name = 'Details' AND table_name = 'Emprunt' AND xid = v_nom_utilisateur AND start_timestamp >= v_date
			GROUP BY xid, start_timestamp;
		ELSE
			SELECT count(*) INTO v_nombre_operations FROM flashback_transaction_query
			WHERE table_name = 'Details' AND table_name = 'Emprunt' AND xid = v_nom_utilisateur
			GROUP BY xid;
		END IF;
	ELSE
		IF(v_date IS NOT NULL) THEN
			SELECT count(*) INTO v_nombre_operations FROM flashback_transaction_query
			WHERE table_name = 'Details' AND table_name = 'Emprunt' AND start_timestamp >= v_date
			GROUP BY start_timestamp;
		ELSE
			SELECT count(*) INTO v_nombre_operations FROM flashback_transaction_query
			WHERE table_name = 'Details' AND table_name = 'Emprunt';
		END IF;	
	END IF;
	Return v_nombre_operations;
END;

/* 9 Si tous les exemplaires référencés sur une fiche ont été rendus, alors interdire tout nouvel
ajout de détails.*/

CREATE OR REPLACE TRIGGER trg_fiche_emprunt
	BEFORE INSERT ON Details
	FOR EACH ROW
DECLARE
	v_nombre_livre_rendu INTEGER;
	v_nombre_livre INTEGER;
BEGIN
	SELECT count(*) INTO v_nombre_livre FROM Details D
	WHERE D.numero_emprunt = :old.numero_emprunt 
	GROUP BY D.numero_emprunt;
	SELECT count(*) INTO v_nombre_livre_rendu FROM Details D, Emprunt E
	WHERE D.numero_emprunt = :old.numero_emprunt AND E.numero_emprunt = D.numero_emprunt AND E.etat = 'RE' 
	GROUP BY D.numero_emprunt;
	IF(v_nombre_livre = v_nombre_livre_rendu) THEN
		RAISE_APPLICATION_ERROR(-20200,'Opération interdite');
	END IF;
END;
