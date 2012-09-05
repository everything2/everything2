/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Dumping routines for database 'everything'
--
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = latin1 */ ;
/*!50003 SET character_set_results = latin1 */ ;
/*!50003 SET collation_connection  = latin1_swedish_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50020 DEFINER=`everyuser`@`%`*/ /*!50003 FUNCTION `ip_to_uint`(ipin VARCHAR(255)) RETURNS int(10) unsigned
    DETERMINISTIC
BEGIN
    RETURN (CAST(SUBSTRING_INDEX(ipin,'.',1) AS UNSIGNED) * 256 * 256 * 256)
     + (CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(ipin,'.',2),'.',-1) AS UNSIGNED) * 256 * 256)
     + (CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(ipin,'.',3),'.',-1) AS UNSIGNED) * 256)
     + (CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(ipin,'.',4),'.',-1)  AS UNSIGNED))
     ;
  END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = latin1 */ ;
/*!50003 SET character_set_results = latin1 */ ;
/*!50003 SET collation_connection  = latin1_swedish_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50020 DEFINER=`everyuser`@`%`*/ /*!50003 PROCEDURE `fixup_blacklistref`()
BEGIN
   DECLARE bl_id int;
   SELECT MIN(ipblacklist_id) INTO bl_id
     FROM ipblacklist
     WHERE ipblacklistref_id = 0
       OR ipblacklistref_id IS NULL
     ;
   WHILE bl_id IS NOT NULL DO
     INSERT INTO ipblacklistref
       ()
       VALUES
       ()
       ;
     UPDATE ipblacklist
       SET ipblacklistref_id = LAST_INSERT_ID()
       WHERE ipblacklist_id = bl_id
       ;
     SELECT MIN(ipblacklist_id) INTO bl_id
       FROM ipblacklist
       WHERE ipblacklistref_id = 0
         OR ipblacklistref_id IS NULL
       ;
   END WHILE;
   SELECT MIN(ipblacklistrange_id) INTO bl_id
     FROM ipblacklistrange
     WHERE ipblacklistref_id = 0
       OR ipblacklistref_id IS NULL
     ;
   WHILE bl_id IS NOT NULL DO
     INSERT INTO ipblacklistref
       ()
       VALUES
       ()
       ;
     UPDATE ipblacklistrange
       SET ipblacklistref_id = LAST_INSERT_ID()
       WHERE ipblacklistrange_id = bl_id
       ;
     SELECT MIN(ipblacklistrange_id) INTO bl_id
       FROM ipblacklistrange
       WHERE ipblacklistref_id = 0
         OR ipblacklistref_id IS NULL
       ;
   END WHILE;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = latin1 */ ;
/*!50003 SET character_set_results = latin1 */ ;
/*!50003 SET collation_connection  = latin1_swedish_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50020 DEFINER=`everyuser`@`%`*/ /*!50003 PROCEDURE `get_recent_softlink`(IN input_user_id INT, IN destination_node_id INT)
    MODIFIES SQL DATA
BEGIN
  DECLARE recent_source_node_id           INT;
  DECLARE scid                            INT;

  START TRANSACTION;
  SELECT softlink_creation_id, from_node
    INTO scid, recent_source_node_id
    FROM softlink_creation
    WHERE creater_user_id = input_user_id
        AND to_node = destination_node_id
        AND displayed = 0
    ORDER BY create_time ASC
    LIMIT 1
    FOR UPDATE
    ;
  IF scid IS NOT NULL THEN
    UPDATE softlink_creation
      SET displayed = 1
      WHERE softlink_creation_id = scid
      ;
  END IF;

  SELECT recent_source_node_id;

  COMMIT;

END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = latin1 */ ;
/*!50003 SET character_set_results = latin1 */ ;
/*!50003 SET collation_connection  = latin1_swedish_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50020 DEFINER=`everyuser`@`%`*/ /*!50003 PROCEDURE `update_time`(IN input_user_id INT)
    MODIFIES SQL DATA
BEGIN
  DECLARE seconds_since_last           INT;

  START TRANSACTION;
  SELECT TIMESTAMPDIFF(SECOND, lasttime, NOW()) INTO seconds_since_last
    FROM user
    WHERE user_id = input_user_id
    FOR UPDATE
    ;
  UPDATE user
    SET lasttime = NOW()
    WHERE user_id = input_user_id
    ;

  SELECT seconds_since_last;

  COMMIT;

END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2012-09-05  0:49:52
