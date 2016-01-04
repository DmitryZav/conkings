
-----------------------------------------------------------------------------
-- Copyright (c) 2010-2015 Dmitry Vazhenin <DmitryZav@users.noreply.github.com>
-- https://github.com/DmitryZav/
--
-- This file is part of Constellation Kings game project.
--
-- This file is subject to the terms and conditions defined in
-- file 'LICENSE', which is part of this source code package. 
------------------------------------------------------------------------------
-- updateDigging
--
-- process resource and artefacts digging actions
-- part of the turn calculation
------------------------------------------------------------------------------
DELIMITER $$

CREATE DEFINER=`xgameuser`@`localhost` PROCEDURE `updateDigging`()
BEGIN

  DECLARE done INT DEFAULT 0;
  DECLARE _FleetId INT UNSIGNED;
  DECLARE _AccountId INT UNSIGNED;
  DECLARE _PlanetId INT UNSIGNED;
  DECLARE _PlanetType INT;
  DECLARE _PlanetArtefacts FLOAT;

  DECLARE FleetCursor CURSOR FOR SELECT FleetId, PlanetId, FleetAccountId, PlanetTypeId, PlanetArtefacts*0.5 FROM 
  (SELECT FleetId, PlanetId, PlanetTypeId, PlanetArtefacts, FleetAccountId FROM Fleets JOIN Sectors ON 
  (FleetState=12 AND FleetCGalaxy=SectorGalaxyId AND FleetCSector=SectorNumber) 
  JOIN Stars ON (SectorId=StarSectorId AND FleetCX = StarX AND FleetCY = StarY) 
  JOIN Planets ON (PlanetStarId=StarId AND PlanetX=FleetLocalX AND PlanetY=FleetLocaly) 
  ORDER BY RAND() ) A GROUP BY PlanetId;

  DECLARE CONTINUE HANDLER FOR SQLSTATE '02000' SET done=1;


  call config();


  OPEN FleetCursor;
  FETCH FleetCursor INTO  _FleetId, _PlanetId, _AccountId, _PlanetType, _PlanetArtefacts;
  WHILE done = 0 DO

    fetch_cur: BEGIN

    IF  _PlanetType<>2 THEN
      UPDATE Fleets SET FleetState=0 WHERE FleetId=_FleetId;
      call postMessage(_AccountId, 3, CONCAT('"template"=>"dig_noplanet", "fleetid"=>"', _FleetId,
       '", "planetid"=>"', _PlanetId, '"'), _PlanetId);
      LEAVE fetch_cur;
    END IF;

    SELECT MAX(UnitEffectValue) FROM Fleets JOIN Units ON (UnitFleetId=FleetId) JOIN UnitTypes USING (UnitTypeId)
    JOIN UnitTypeEffects USING (UnitTypeId) JOIN EffectTypes ON (EffectTypeId=UnitEffectId) 
    WHERE EffectTypeName='unit_dig' AND FleetId=_FleetId GROUP BY UnitFleetId 
    INTO @UnitEffect;

    IF @UnitEffect IS NULL 
     THEN
      UPDATE Fleets SET FleetState=0 WHERE FleetId=_FleetId;
      call postMessage(_AccountId, 3, CONCAT('"template"=>"dig_nounit", "fleetid"=>"', _FleetId,
       '", "planetid"=>"', _PlanetId, '","dip"=>1'), _PlanetId);
      LEAVE fetch_cur;
    END IF;

  SET @MineVal = (SELECT GET_RESEARCH(_AccountId, 1, 1));
  
  SET @Turn = (SELECT CURRENT_TURN());
  SET @ResourceId = (SELECT PlanetResourceTypeId FROM PlanetResources WHERE PlanetResourcePlanetId=_PlanetId LIMIT 1);
  SET @ResValue = (SELECT ROUND(20*@UnitEffect*PlanetResourceQuantity*@MineVal) 
    FROM PlanetResources WHERE PlanetResourcePlanetId=_PlanetId AND PlanetResourceTypeId=@ResourceId);

  SET @FirstBox = 1;
	
  WHILE @ResValue>0 DO

   SET @UnitId=(SELECT U.UnitId FROM Units U JOIN UnitTypeContainer CT ON ( CT.UnitTypeId=U.UnitTypeId) JOIN Fleets ON ( FleetId = UnitFleetId )
     JOIN UnitInstContainer UI ON ( U.UnitId = UI.UnitId
    AND UnitInstContainerResourceId = @ResourceId AND UnitInstContainerStampId =_AccountId )
     WHERE FleetId =_FleetId AND UnitTypeContainerMaxMass> IFNULL(UnitInstContainerValue, 0) LIMIT 1);


  IF IFNULL(@UnitId, 0)>0 THEN
   UPDATE UnitInstContainer C 
      SET UnitInstContainerValue=UnitInstContainerValue+@ResValue 
	WHERE C.UnitId=@UnitId AND C.UnitInstContainerResourceId=@ResourceId ;
  ELSE
     SET @UnitId=(SELECT U.UnitId FROM Units U JOIN UnitTypeContainer UC ON ( UC.UnitTypeId=U.UnitTypeId)
     JOIN Fleets ON ( FleetId = UnitFleetId ) LEFT JOIN UnitInstContainer C ON ( C.UnitId=U.UnitId)
     WHERE FleetId =_FleetId AND C.UnitId IS NULL AND UnitQuantity=1 LIMIT 1);

     IF IFNULL(@UnitId, 0) > 0 THEN

       INSERT INTO UnitInstContainer(UnitId, UnitInstContainerUnitId, UnitInstContainerResourceId, UnitInstContainerValue,
        UnitInstContainerStampId, UnitInstContainerStampName, UnitInstContainerTurn)
       SELECT @UnitId, NULL, @ResourceId, @ResValue, AccountId, AccountName, @Turn
       FROM Accounts  WHERE  AccountId=_AccountId LIMIT 1;
      ELSE

       SET @UnitId=(SELECT U.UnitId FROM Units U JOIN UnitTypeContainer USING ( UnitTypeId )
        JOIN Fleets ON ( FleetId = UnitFleetId ) LEFT JOIN UnitInstContainer C ON ( C.UnitId=U.UnitId)
        WHERE FleetId =_FleetId AND C.UnitId IS NULL AND UnitQuantity>1 LIMIT 1);

       IF IFNULL(@UnitId, 0) > 0 THEN

         INSERT INTO Units (UnitId, UnitTypeId, UnitFleetId, UnitQuantity, UnitHealth)
         SELECT 0, UnitTypeId, UnitFleetId, UnitQuantity-1, UnitHealth FROM Units WHERE UnitId=@UnitId;
         UPDATE Units SET UnitQuantity=1 WHERE UnitId=@UnitId;

         INSERT INTO UnitInstContainer(UnitId, UnitInstContainerUnitId, UnitInstContainerResourceId, UnitInstContainerValue,
         UnitInstContainerStampId, UnitInstContainerStampName, UnitInstContainerTurn)
         SELECT @UnitId, NULL, @ResourceId, @ResValue, AccountId, AccountName, @Turn
         FROM Accounts  WHERE  AccountId=_AccountId LIMIT 1;

       ELSE
		  IF _PlanetArtefacts < 0.0001 THEN
         
            UPDATE Fleets SET FleetState=0 WHERE FleetId=_FleetId;
            call postMessage(_AccountId, 3, CONCAT('"template"=>"dig_nobox", "fleetid"=>"', _FleetId,
            '", "planetid"=>"', _PlanetId, '","dip"=>1'), _PlanetId);
            LEAVE fetch_cur;

          END IF;

       END IF;
     END IF;

    END IF;     

   SET @ResValue = (SELECT UnitInstContainerValue - UnitTypeContainerMaxMass
	                FROM UnitInstContainer C JOIN Units U ON(C.UnitId=U.UnitId) 
                        JOIN UnitTypeContainer USING(UnitTypeId)
 			WHERE C.UnitId=@UnitId );   

    UPDATE UnitInstContainer C, (SELECT UnitTypeContainerMaxMass 
	                         FROM UnitTypeContainer CT JOIN Units U ON(CT.UnitTypeId=U.UnitTypeId)
				 WHERE U.UnitId=@UnitId) T
	  SET UnitInstContainerValue=T.UnitTypeContainerMaxMass 
    WHERE UnitInstContainerValue > UnitTypeContainerMaxMass AND C.UnitId=@UnitId;

   SET @BoxFull = (SELECT UnitInstContainerValue - UnitTypeContainerMaxMass 
     FROM UnitTypeContainer CT JOIN Units U ON(CT.UnitTypeId=U.UnitTypeId) JOIN UnitInstContainer CI ON (CI.UnitId = U.UnitId)
       WHERE U.UnitId=@UnitId );
  
   IF (@FirstBox =1 AND @ResValue>=0) OR (@ResValue<=0 AND @BoxFull=0)  THEN
      call postMessage(_AccountId, 3, CONCAT('"template"=>"dig_boxfull", "fleetid"=>"', _FleetId,
       '", "planetid"=>"', _PlanetId, '","dip"=>1'), _PlanetId);
   END IF;

   SET @FirstBox := 0;
	
   END WHILE;
  
   IF _PlanetArtefacts > 0  AND RAND() < _PlanetArtefacts THEN

     INSERT INTO Units(UnitId, UnitTypeId, UnitFleetId, UnitQuantity, UnitHealth, UnitDisabled)
     SELECT 0, UnitTypeId, _FleetId, 1, UnitTypeHealth, 0
     FROM UnitTypes WHERE UnitTypeId = @_DigBoxId;
     SET @FullBoxId := LAST_INSERT_ID();
     SET @MaxLevel := (SELECT MAX(DetailLevel) FROM DesignerDetails WHERE DetailArtefact=1);
     SET @ArtLevel := (SELECT CEIL(GAUSS_TRUNC(0,4,0,@MaxLevel)));
    
     SELECT DetailId FROM DesignerDetails WHERE DetailLevel=@ArtLevel AND
     DetailArtefact= 1 ORDER BY RAND() LIMIT 1 INTO @ArtId;

     SET @ArtAccId = (SELECT CEIL(RAND()*4));

     INSERT INTO UnitInstContainer(UnitId, UnitInstContainerUnitId, 
     UnitInstContainerResourceId, UnitInstContainerValue, UnitInstContainerStampId, 
     UnitInstContainerStampName, UnitInstContainerTurn, UnitInstContainerPackLen, 
     UnitInstContainerHostId, UnitInstContainerDetailId, 
     UnitInstContainerDetailOwnerId)
     SELECT @FullBoxId, NULL, NULL, FLOOR(RAND() * 50 / @ArtLevel) + 1, AccountId, AccountName, 
     CURRENT_TURN(), NULL, NULL, @ArtId, AccountId
     FROM Accounts WHERE AccountId = @ArtAccId;

     UPDATE Planets SET PlanetArtefacts = PlanetArtefacts/2.0  
     WHERE PlanetId = _PlanetId;

     call postMessage(_AccountId, 3, CONCAT('"template"=>"dig_artefact", "fleetid"=>"', _FleetId,
       '", "planetid"=>"', _PlanetId, '","dip"=>1'), _PlanetId);

     IF _PlanetArtefacts < 0.0021 THEN
       UPDATE Planets P, (SELECT PlanetId FROM Planets LEFT JOIN Fleets ON (FleetHostId = PlanetId) 
       WHERE PlanetArtefacts < 0.002 AND PlanetTypeId=2 AND FleetHostId IS NULL LIMIT 1) F
       SET PlanetArtefacts = 0.04*RAND()
       WHERE P.PlanetId=F.PlanetId;
     END IF;

   END IF;

   END  fetch_cur;
   FETCH FleetCursor INTO  _FleetId, _PlanetId, _AccountId, _PlanetType, _PlanetArtefacts;

  END WHILE;
  CLOSE FleetCursor;


END
