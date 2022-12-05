-- Create your tables, views, functions and procedures here!
CREATE SCHEMA destruction;
USE destruction;

CREATE TABLE players (
  player_id INT UNSIGNED PRIMARY KEY NOT NULL AUTO_INCREMENT,
  first_name VARCHAR(30) NOT NULL,
  last_name VARCHAR(30) NOT NULL,
  email VARCHAR(50) NOT NULL
);

CREATE TABLE characters (
  character_id INT UNSIGNED PRIMARY KEY NOT NULL AUTO_INCREMENT,
  player_id INT UNSIGNED NOT NULL,
  name VARCHAR(30) NOT NULL,
  level TINYINT UNSIGNED NOT NULL,
  CONSTRAINT characters_fk_players
    FOREIGN KEY (player_id)
    REFERENCES players (player_id)
    ON UPDATE CASCADE
    ON DELETE CASCADE 
);

CREATE TABLE winners (
  character_id INT UNSIGNED PRIMARY KEY NOT NULL AUTO_INCREMENT,
  name VARCHAR (30) NOT NULL,
  CONSTRAINT winners_fk_characters
    FOREIGN KEY (character_id)
    REFERENCES characters (character_id)
    ON UPDATE CASCADE
    ON DELETE CASCADE 
);

CREATE TABLE character_stats (
  character_id INT UNSIGNED PRIMARY KEY NOT NULL AUTO_INCREMENT,
  health INT DEFAULT 0,
  armor INT UNSIGNED DEFAULT 0,
  CONSTRAINT character_stats_fk_players
    FOREIGN KEY (character_id)
    REFERENCES characters (character_id)
    ON UPDATE CASCADE
    ON DELETE CASCADE  
);

CREATE TABLE teams (
	team_id INT UNSIGNED PRIMARY KEY NOT NULL AUTO_INCREMENT,
  name VARCHAR(30) NOT NULL 
);

CREATE TABLE team_members (
  team_member_id  INT UNSIGNED PRIMARY KEY NOT NULL AUTO_INCREMENT,
  team_id INT UNSIGNED NOT NULL,
  character_id INT UNSIGNED NOT NULL,
  CONSTRAINT team_members_fk_teams
  FOREIGN KEY (team_id) 
    REFERENCES teams (team_id)
    ON UPDATE CASCADE
    ON DELETE CASCADE,       
CONSTRAINT team_members_fk_characters
FOREIGN KEY (character_id) 
 REFERENCES characters (character_id)
 ON UPDATE CASCADE
 ON DELETE CASCADE   
);

CREATE TABLE items (
  item_id  INT UNSIGNED PRIMARY KEY NOT NULL AUTO_INCREMENT,
  name VARCHAR(30) NOT NULL,
  armor INT UNSIGNED DEFAULT 0,
  damage INT UNSIGNED DEFAULT 0    
);

CREATE TABLE inventory (
  inventory_id INT UNSIGNED PRIMARY KEY NOT NULL AUTO_INCREMENT,
  character_id INT UNSIGNED NOT NULL,
  item_id INT UNSIGNED NOT NULL,
  CONSTRAINT inventory_fk_characters
  FOREIGN KEY (character_id) 
    REFERENCES characters (character_id)
    ON UPDATE CASCADE
    ON DELETE CASCADE,       
    CONSTRAINT inventory_fk_items
    FOREIGN KEY (item_id) 
       REFERENCES items (item_id)
       ON UPDATE CASCADE
       ON DELETE CASCADE       
);

CREATE TABLE equipped (
  equipped_id INT UNSIGNED PRIMARY KEY NOT NULL AUTO_INCREMENT,
  character_id INT UNSIGNED NOT NULL,
  item_id INT UNSIGNED NOT NULL,
  CONSTRAINT equipped_fk_characters
  FOREIGN KEY (character_id) 
     REFERENCES characters (character_id)
     ON UPDATE CASCADE
     ON DELETE CASCADE,      
   CONSTRAINT equipped_fk_items
	FOREIGN KEY (item_id) 
        REFERENCES items (item_id)
         ON UPDATE CASCADE
	 ON DELETE CASCADE
);

CREATE OR REPLACE VIEW character_items AS
SELECT c.character_id, c.name AS character_name, i.name AS item_name, i.armor , i.damage
FROM characters c
    INNER JOIN inventory iv
    ON c.character_id = iv.character_id
    INNER JOIN items i
    ON iv.item_id = i.item_id
    UNION 
    SELECT c.character_id, c.name AS character_name, i.name AS item_name, i.armor , i.damage
    FROM characters c
    INNER JOIN equipped e
    ON c.character_id = e.character_id
    INNER JOIN items i
    ON e.item_id = i.item_id 
    ORDER BY character_name, item_name;
    
CREATE OR REPLACE VIEW team_items AS
    SELECT t.team_id, t.name AS team_name, i.name AS item_name, i.armor , i.damage
    FROM teams t
    INNER JOIN team_members te
    ON t.team_id = te.team_id
    INNER JOIN characters c
    ON c.character_id = te.character_id
    INNER JOIN inventory iv
    ON c.character_id = iv.character_id
    INNER JOIN items i
    ON iv.item_id = i.item_id
    UNION 
    SELECT t.team_id, t.name AS team_name, i.name AS item_name, i.armor , i.damage
    FROM teams t
    INNER JOIN team_members te
    ON t.team_id = te.team_id
    INNER JOIN characters c
    ON c.character_id = te.character_id
    INNER JOIN equipped e
    ON c.character_id = e.character_id
    INNER JOIN items i
    ON e.item_id = i.item_id 
    ORDER BY team_name, item_name;
    
DELIMITER ;;
    CREATE FUNCTION armor_total(id INT UNSIGNED)
    RETURNS INT UNSIGNED 
    DETERMINISTIC 
    BEGIN 
    DEClARE character_armor INT UNSIGNED;
    DEClARE equipped_armor INT UNSIGNED;
    DECLARE total_armor INT UNSIGNED;

    SELECT armor  INTO character_armor
    FROM character_stats 
    WHERE character_id = id;

    SELECT SUM(i.armor) INTO equipped_armor 
    FROM items i
    LEFT OUTER JOIN equipped e
    ON e.item_id = i.item_id
    WHERE e.character_id = id;

    SET total_armor = character_armor + equipped_armor;
        RETURN total_armor;

    END;; 
     
DELIMITER ;;

CREATE PROCEDURE attack(attacked_character_id INT UNSIGNED, equipped_id INT UNSIGNED)

BEGIN
DECLARE armor INT UNSIGNED;
DECLARE damage INT UNSIGNED;
DECLARE total_damage INT;
DECLARE new_health INT;
DECLARE total_health INT;


SELECT armor_total(attacked_character_id) INTO armor;

SELECT i.damage INTO damage 
    FROM items i
    	INNER JOIN equipped e
    	ON e.item_id = i.item_id
    WHERE e.equipped_id = equipped_id;
SET total_damage = damage - armor;

SELECT health INTO new_health
    FROM character_stats
    WHERE character_id = attacked_character_id ;

IF total_damage > 0 THEN 

    SET total_health = new_health - total_damage;
    UPDATE character_stats SET health = total_health WHERE character_id = attacked_character_id;

    IF  total_damage > = new_health THEN
    DELETE FROM characters WHERE character_id = attacked_character_id;
    END IF;
END IF;
END;;
DELIMITER ;

DELIMITER ;;
CREATE PROCEDURE equip (item_inventory_id INT UNSIGNED)
BEGIN
DECLARE item INT UNSIGNED;
DECLARE id_character INT UNSIGNED;
DECLARE new_item INT UNSIGNED;
DECLARE new_character INT UNSIGNED;

SELECT item_id INTO item
FROM inventory
WHERE inventory_id = item_inventory_id;

SELECT item_id INTO new_item
FROM items 
WHERE item_id = item;

SELECT character_id INTO id_character
FROM inventory
WHERE inventory_id = item_inventory_id;

SELECT character_id INTO new_character
FROM characters 
WHERE character_id = id_character;

DELETE FROM inventory WHERE inventory_id = item_inventory_id;

INSERT INTO equipped (character_id, item_id) VALUES (new_character, new_item);
END;;
DELIMITER ;

DELIMITER ;;
CREATE PROCEDURE unequip (item_equipped_id INT UNSIGNED)
BEGIN
DECLARE item INT UNSIGNED;
DECLARE id_character INT UNSIGNED;
DECLARE new_item INT UNSIGNED;
DECLARE new_character INT UNSIGNED;

SELECT item_id INTO item
FROM equipped
WHERE equipped_id = item_equipped_id;

SELECT item_id INTO new_item
FROM items
WHERE item_id = item;

SELECT character_id INTO id_character
FROM equipped
WHERE equipped_id = item_equipped_id;

SELECT character_id INTO new_character
FROM characters
WHERE character_id = id_character;

DELETE FROM equipped WHERE equipped_id = item_equipped_id;

INSERT INTO inventory (character_id, item_id) VALUES (new_character,new_item );
END;;

CREATE PROCEDURE set_winners(id_team INT UNSIGNED)
BEGIN

DECLARE team INT UNSIGNED;
DECLARE id INT UNSIGNED;
DECLARE character_name VARCHAR(30);
DECLARE row_not_found TINYINT DEFAULT FALSE;

DECLARE team_cursor CURSOR FOR

SELECT c.character_id, c.name
FROM team_members t
INNER JOIN characters c
ON t.character_id = c.character_id
WHERE t.team_id = id_team;


DECLARE CONTINUE HANDLER FOR NOT FOUND
SET row_not_found = TRUE;

DELETE FROM winners;

OPEN team_cursor;
character_loop : LOOP

FETCH team_cursor INTO id, character_name;

IF row_not_found THEN
LEAVE character_loop;
END IF;

INSERT INTO winners
(character_id , name)
VALUES
(id, character_name);

END LOOP character_loop;

CLOSE team_cursor;

END;;
DELIMITER ;
