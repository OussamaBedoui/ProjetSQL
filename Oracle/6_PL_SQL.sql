-- 1 -- Mise à jour conditionnelle : tous les exemplaires ont été enregistrés avec l’état neuf, mais au fur et à mesure des emprunts, leur état s’est dégradé. Il s’agit maintenant de mettre à jour l’état de chacun en fonction du nombre de fois que l’exemplaire a été emprunté. En effet, le nombre d’emprunteurs a plus d’incidence sur l’état général de l’exemplaire que la durée effective des emprunts.

DECLARE
	CURSOR c_exemplaire IS
		SELECT * FROM Exemplaire FOR UPDATE OF etat;
	v_etat exemplaire.etat%type;
	v_nombre_emprunts number(3);
BEGIN
	FOR v_exemplaire IN c_exemplaire LOOP
		SELECT count(*) INTO v_nombre_emprunts
		FROM Details
		WHERE Details.isbn = v_exemplaire.isbn AND Details.numero_exemplaire = v_exemplaire.numero_exemplaire;
		IF (v_nombre_emprunts <= 10) THEN
			v_etat := 'Neuf';		
			ELSE IF (v_nombre_emprunts <= 25) THEN
				v_etat := 'Bon';
				ELSE IF (v_nombre_emprunts <= 40) THEN
					v_etat := 'Moyen';
					ELSE
						v_etat := 'Mauvais';
					END IF;
				END IF;
		END IF;
		UPDATE Exemplaire SET etat = v_etat
		WHERE CURRENT OF c_exemplaire;
	END LOOP;
END;

/* 2 Ecrivez un bloc PL/SQL qui permet de supprimer les membres dont l’adhésion a expiré
depuis plus de 2 ans.
Si des fiches d’emprunts existent et si les exemplaires empruntés ont été rendus, alors mettre à
NULL la valeur présente dans la colonne MEMBRE.
S’il reste des livres empruntés et non rendus, alors ne pas supprimer le membre.*/

DECLARE
	CURSOR c_membre IS SELECT * FROM Membre
	WHERE MONTHS_BETWEEN(SYSDATE, ADD_MONTHS(date_adhere, duree)) > 24;
	v_nombre number(5);
BEGIN	
	FOR v_membre IN c_membre LOOP
		SELECT count(*) INTO v_nombre
		FROM Details, Emprunt
		WHERE date_de_rendu IS NULL AND Details.numero_emprunt = Emprunt.numero_emprunt AND Emprunt.numero_membre = v_membre.numero_membre;
		IF (v_nombre != 0) THEN
			UPDATE Emprunt SET numero_membre = NULL
			WHERE numero_membre = v_membre.numero_membre;
		ELSE
			SELECT count(*) INTO v_nombre FROM Emprunt WHERE numero_membre = v_membre.numero_membre;
			DELETE FROM Membre WHERE numero_membre = v_membre.numero_membre;
			COMMIT;
		END IF;
	END LOOP;
END;

/* 3 Ecrire un bloc PL/SQL qui permet d’éditer la liste des trois membres qui ont emprunté le
plus d’ouvrages au cours des dix derniers mois et établissez également la liste des trois
membres qui ont emprunté moins.*/

-- Permet de faire des sorties DBMS
Set serverouput on

DECLARE
	CURSOR c_meilleur IS SELECT E.numero_membre, count(*)
	FROM Emprunt E, Details D
	WHERE E.numero_emprunt = D.numero_emprunt AND MONTHS_BETWEEN(SYSDATE, date_emprunt) <= 10 
	GROUP BY E.numero_membre
	ORDER BY 2 ASC;

	CURSOR c_mauvais IS SELECT E.numero_membre, count(*)
	FROM Emprunt E, Details D
	WHERE E.numero_emprunt = D.numero_emprunt AND MONTHS_BETWEEN(SYSDATE, date_emprunt) <= 10 
	GROUP BY E.numero_membre
	ORDER BY 2 DESC;

	v_membre Membre%rowtype;
	v_numero_membre c_meilleur%rowtype;
	i NUMBER;
BEGIN
	DBMS_OUTPUT.PUT_LINE('Les membres ayant emprunté le plus sont :');
	OPEN c_meilleur;
	FOR i IN 1..3 LOOP
		FETCH c_meilleur INTO v_numero_membre;
		SELECT * INTO v_membre
		FROM Membre
		WHERE numero_membre = v_numero_membre.numero_membre;
	DBMS_OUTPUT.PUT_LINE(i||') '||v_membre.numero_membre ||' '||v_membre.nom);
	END LOOP;
	CLOSE c_meilleur;
	DBMS_OUTPUT.PUT_LINE('Les membres ayant le moins empruntés sont :');
	OPEN c_mauvais;
	FOR i IN 1..3 LOOP
		FETCH c_mauvais INTO v_numero_membre;
		SELECT * INTO v_membre
		FROM Membre
		WHERE numero_membre = v_numero_membre.numero_membre;
	DBMS_OUTPUT.PUT_LINE(i||') '||v_membre.numero_membre ||' '||v_membre.nom);
	END LOOP;
	CLOSE c_mauvais;
END;


/* 4 Ecrivez un bloc PL/SQL qui permet de connaître les cinq ouvrages les plus empruntés.*/

Set serverouput on

DECLARE
	CURSOR c_ouvrage IS SELECT isbn, count(*) AS nombre_emprunts
	FROM Details
	GROUP BY isbn
	ORDER BY 2 DESC;
	
	v_ouvrage c_ouvrage%rowtype;
	i NUMBER;
BEGIN 
	OPEN c_ouvrage;
	DBMS_OUTPUT.PUT_LINE('ISBN des ouvrages les plus empruntés :');
	FOR i IN 1..5 LOOP
		FETCH c_ouvrage INTO v_ouvrage;
		EXIT WHEN c_ouvrage%notfound;
		DBMS_OUTPUT.PUT_LINE('Numéro : '||i||', isbn :' || v_ouvrage.isbn);
	END LOOP;
	CLOSE c_ouvrage;
END;

/* 5 Etablissez la liste des membres dont l’adhésion a expiré, ou bien qui va expirer dans les 30
prochains jours. Affichez la liste à l’écran. */

Set serverouput on

DECLARE
	CURSOR c_membre IS SELECT * FROM Membre;
BEGIN
	FOR v_membre IN c_membre LOOP
		IF (ADD_MONTHS(v_membre.date_adhere, v_membre.duree) < SYSDATE + 30) THEN
			DBMS_OUTPUT.PUT_LINE('Numero ' || v_membre.numero_membre || ', nom '|| v_membre.nom);
		END IF;
	END LOOP;
END;

/* 6 Les exemplaires sont tous achetés à l’état neuf. Pour calculer leur état actuel, il faut être
capable de connaître le nombre de fois où ils ont été empruntés. Mais les membres sont
nombreux et il est impossible de conserver de nombreuses années en ligne tout ce qui
concerne le détail des locations.
Un exemplaire est considéré comme emprunté à partir du moment où il est présent sur une
fiche d’emprunt. C’est donc la date de création de la fiche qui permet de savoir quand le livre
a été emprunté.
Au niveau des exemplaires, une colonne de type date va être ajoutée afin de connaître la date
du dernier calcul de mise à jour de l’état. Lors de l’exécution du bloc PL/SQL, seuls les
emprunts effectués, depuis cette date, seront pris en compte. Afin que la mise à jour de l’état
de l’exemplaire soit effectuée de la façon la plus juste, une seconde colonne va être ajoutée
afin de mémoriser le nombre d’emprunts pour cet exemplaire.

a) Ecrivez un script pour effectuer les modifications de structure demandées.
*/

ALTER TABLE Exemplaire ADD nombre_emprunts NUMBER DEFAULT 0;
ALTER TABLE Exemplaire ADD date_calcul_emprunt DATE DEFAULT SYSDATE;


/*Pour chaque exemplaire, la valeur par défaut au moment de la création dans la colonne
DATECALCULDEMPRUNTS doit correspondre à la date de premier emprunt de cet
exemplaire par l’un des membres, ou bien la date du jour si cet exemplaire n’a pas encore été
emprunté.*/
UPDATE Exemplaire SET date_calcul_emprunt = SYSDATE; -- Optionnelle ?
UPDATE Exemplaire SET date_calcul_emprunt = (SELECT min(date_emprunt) FROM Emprunt E, Details D
	WHERE E.numero_emprunt = D.numero_emprunt AND D.isbn = Exemplaire.isbn AND D.numero_exemplaire = Exemplaire.numero_exemplaire);

/*b) Ecrivez le bloc PL/SQL qui permet de mettre à jour les informations sur la table des
exemplaires.*/

DECLARE
	CURSOR c_exemplaire IS
		SELECT * FROM Exemplaire
		FOR UPDATE OF nombre_emprunts;
	
	v_nombre_emprunts Exemplaire.nombre_emprunts%type;
BEGIN
	FOR v_exemplaire IN c_exemplaire LOOP
		SELECT count(*) INTO v_nombre_emprunts
		FROM Details D, Emprunt E
		WHERE D.numero_emprunt = E.numero_emprunt AND isbn = v_exemplaire.isbn AND numero_exemplaire = v_exemplaire.numero_exemplaire AND date_emprunt >= v_exemplaire.date_calcul_emprunt;
		UPDATE Exemplaire SET nombre_emprunts = nombre_emprunts + v_nombre_emprunts
		WHERE CURRENT OF c_exemplaire;

		UPDATE Exemplaire SET etat = 'Neuf' WHERE nombre_emprunts <= 10;
		UPDATE Exemplaire SET etat = 'Bon' WHERE nombre_emprunts BETWEEN 11 AND 25;
		UPDATE Exemplaire SET etat = 'Moyen' WHERE nombre_emprunts BETWEEN 26 AND 40;
		UPDATE Exemplaire SET etat = 'Mauvais' WHERE nombre_emprunts >= 41;
	END LOOP;
END;
	
/* 7 Si plus de la moitié des exemplaires sont dans l’état Moyen ou Mauvais alors modifiez la
contrainte d’intégrité afin que les différents états possibles d’un exemplaire soient : Neuf,
Bon, Moyen, Douteux ou Mauvais.
Un exemplaire est dans l’état Douteux lorsqu’il a été emprunté entre 40 et 60 fois. Il est dans
l’état Mauvais lorsqu’il a été emprunté plus de 60 fois. */

DECLARE
	v_nombre_douteux NUMBER;
	v_total NUMBER;
BEGIN
	SELECT count(*) INTO v_nombre_douteux
	FROM Exemplaire
	WHERE etat in ('Moyen','Mauvais');
	
	SELECT count(*) INTO v_total
	FROM Exemplaire;
	
	IF (v_nombre_douteux > v_total / 2) THEN
		EXECUTE IMMEDIATE 'ALTER TABLE Exemplaire DROP constraint ck_exemplaire_etat';
		EXECUTE IMMEDIATE 'ALTER TABLE Exemplaire ADD constraint ck_exemplaire_etat CHECK IN (''Neuf'',''Bon'',''Moyen'',''Mauvais'',''Douteux'')';
		UPDATE Exemplaire SET etat ='Douteux'
		WHERE nombre_emprunts BETWEEN 41 and 60;
	END IF;
END;

/* 8 Supprimez tous les membres qui n’ont pas effectué d’emprunt d’ouvrage depuis trois ans. */

DELETE FROM Membre
	WHERE numero_membre IN (SELECT DISTINCT numero_membre FROM Emprunt
							GROUP BY numero_membre
							HAVING MAX(date_emprunt) < ADD_MONTHS(SYSDATE, -36));
	
/* 9 Comme cela a été constaté précédemment, les membres possèdent tous un numéro de
téléphone mobile mais ce numéro n’est pas bien formaté et la nouvelle contrainte d’intégrité
ne peut être posée.
Ecrivez un bloc PL/SQL qui permet de s’assurer que tous les numéros de téléphone mobile
des membres respectent le format 06 xx xx xx xx. Puis posez une contrainte d’intégrité pour
vous assurez que tous les numéros possèderont toujours ce format. */

ALTER TABLE Membre MODIFY telephone_portable VARCHAR2(14);
ALTER TABLE Membre DROP CONSTRAINT cc_telephone_portable;

DECLARE
	CURSOR c_membre IS
		SELECT telephone_portable FROM Membre
		FOR UPDATE OF telephone_portable;

	v_new_portable_membre VARCHAR2(14);
BEGIN
	FOR v_membre IN c_membre LOOP
		IF (INSTR(v_membre.telephone_portable, ' ') != 2) THEN
			v_new_portable_membre := SUBSTR(v_membre.telephone_portable, 1, 2)||' '||SUBSTR(v_membre.telephone_portable, 3, 2)||' '||SUBSTR(v_membre.telephone_portable, 5, 2)||' '||SUBSTR(v_membre.telephone_portable, 7, 2)||' '||SUBSTR(v_membre.telephone_portable, 9, 2);
			UPDATE Membre SET telephone_portable = v_new_portable_membre
			WHERE CURRENT OF c_membre;
		END IF;
	END LOOP;
END;

ALTER TABLE Membre ADD CONSTRAINT cc_telepone_portable CHECK (REGEXP_LIKE(telephone_portable, '^06 [0-9]{2} [0-9]{2} [0-9]{2} [0-9]{2}$')); 
