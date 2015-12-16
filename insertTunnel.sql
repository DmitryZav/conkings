-----------------------------------------------------------------------------
-- Copyright (c) 2010-2015 Dmitry Vazhenin <DmitryZav@users.noreply.github.com>
-- https://github.com/DmitryZav/
--
-- This file is part of Constellation Kings game project.
--
-- This file is subject to the terms and conditions defined in
-- file 'LICENSE', which is part of this source code package. 
-----------------------------------------------------------------------------
--
-- insertTunnel procedure: create new tunnel between two portals
-- parameters:
-- _SrcId - source portal fleet id
-- _DestId - destination portal fleet id (if 0, will try to create new one from source fleet)
-- _AccountId - tunnel owner id
-- _StarId - destination star to put the new portal into, if _Dest = 0
-----------------------------------------------------------------------------

delimiter $$

CREATE PROCEDURE `insertTunnel`(_SrcId INT UNSIGNED, _DestId UNSIGNED, _AccountId INT UNSIGNED, _StarId INT UNSIGNED)
BEGIN
sproc:BEGIN

  SET @PortalClassId:=8;
  SET @EnergyRes:=6;


 IF _SrcId = _DestId THEN
      SELECT 'PortalInnerSystem' AS Result;
      LEAVE sproc;
 END IF;

 -- call debug(CONCAT('tunnel s:',_SrcId, 'd:',_DestId,' acc:', _AccountId,' star:', _StarId));

 IF EXISTS (SELECT * FROM Fleets S JOIN Fleets D ON 
            (S.FleetId<>D.FleetId AND S.FleetId=_SrcId AND D.FleetId=_DestId AND 
             S.FleetCGalaxy=D.FleetCGalaxy AND S.FleetCSector=D.FleetCSector
             AND S.FleetCX=D.FleetCX AND S.FleetCY=D.FleetCY)) 
 THEN
     SELECT 'PortalInnerSystem' AS Result;
     LEAVE sproc;
 END IF;


 IF EXISTS (SELECT * FROM Fleets S JOIN Fleets D ON 
            (S.FleetId<>D.FleetId AND S.FleetId=_SrcId AND D.FleetId=_DestId AND 
             (S.FleetCGalaxy<>D.FleetCGalaxy OR S.FleetCSector<>D.FleetCSector))) THEN
 


   SET @MaxLongRoutes := (SELECT MAX_LONG_ROUTES(_AccountId));


   IF (SELECT COUNT(RouteId)+1 
     FROM Routes JOIN Fleets S ON(S.FleetId=RouteSourcePortalId) JOIN 
     Fleets D ON(D.FleetId=RouteDestinationPortalId) 
     WHERE (S.FleetCGalaxy <> D.FleetCGalaxy OR S.FleetCSector <> D.FleetCSector) 
     AND RouteOwnerAccountId=_AccountId) >= @MaxLongRoutes THEN

       SELECT 'RouteLongFailed' AS Result;
       LEAVE sproc;

  END IF;
END IF;



IF (SELECT MAX_ROUTES(_AccountId)-COUNT(*) FROM Routes 
     WHERE RouteOwnerAccountId=_AccountId) <= 0 THEN
       SELECT 'TooManyRoutes' AS Result;
       LEAVE sproc;
END IF;


IF (SELECT UnitInstPortalDegree - COUNT( RouteId )  FROM UnitInstPortal INNER JOIN Units
  USING ( UnitId ) LEFT JOIN Fleets ON ( FleetId = UnitFleetId ) LEFT JOIN Routes ON
  ( RouteSourcePortalId = FleetId OR RouteDestinationPortalId = FleetId ) WHERE FleetId = _SrcId)<=0 THEN
  SELECT 'PortalLowDegree' AS Result;
  LEAVE sproc;
END IF;



SET @ScrUnitId := (SELECT UnitId FROM Fleets INNER JOIN Units ON (FleetId=UnitFleetId)
  	JOIN UnitInstPortal USING(UnitId) WHERE FleetId=_SrcId AND IFNULL(UnitInstPortalDeployed,1) );
IF @ScrUnitId  IS NULL THEN
   SELECT 'PortalOff' AS Result;
   LEAVE sproc;
END IF;


IF _DestId > 0 THEN

 SET @FleetId = _DestId;

 IF EXISTS (SELECT RouteId FROM Routes WHERE RouteSourcePortalId=_SrcId AND RouteDestinationPortalId=_DestId 
    UNION distinct
    SELECT RouteId FROM Routes WHERE RouteSourcePortalId=_DestId AND RouteDestinationPortalId=_SrcId ) THEN

    SELECT 'RouteExists' AS Result;
    LEAVE sproc;
 END IF;

 IF (SELECT UnitInstPortalDegree - COUNT( RouteId )  FROM UnitInstPortal INNER JOIN Units
     USING ( UnitId ) LEFT JOIN Fleets ON ( FleetId = UnitFleetId ) LEFT JOIN Routes ON
     ( RouteSourcePortalId = FleetId OR RouteDestinationPortalId = FleetId ) WHERE FleetId = _DestId)<=0 THEN
     SELECT 'PortalLowDegree' AS Result;
     LEAVE sproc;
 END IF;

  SET @DstUnitId := (SELECT UnitId FROM Fleets INNER JOIN Units ON (FleetId=UnitFleetId)
  	JOIN UnitInstPortal USING(UnitId) WHERE FleetId=_DestId AND IFNULL(UnitInstPortalDeployed,1) );
  IF @DstUnitId  IS NULL THEN
     SELECT 'PortalOff' AS Result;
     LEAVE sproc;
  END IF;


ELSE 

SET @UnitId :=(SELECT UnitId FROM Fleets JOIN Units ON (FleetId=UnitFleetId) INNER JOIN 
    UnitTypes USING (UnitTypeId) JOIN UnitTypePortal USING(UnitTypeId) 
    LEFT JOIN  UnitInstPortal USING (UnitId)
    WHERE UnitFleetId=_SrcId AND FleetAccountId=_AccountId 
    AND IFNULL(UnitInstPortalDeployed, 0)=0 ORDER BY UnitTypePortalSpeed DESC LIMIT 1);

IF @UnitId IS NOT NULL THEN 

  SET @CooId = (
    SELECT id FROM ListCoordinate WHERE id NOT IN (
      SELECT DISTINCT id FROM ListCoordinate JOIN Planets
      ON ( POW(PlanetX-x,2)+POW(PlanetY-y,2)<=4 AND PlanetStarId=_StarId)
      UNION distinct
      SELECT DISTINCT id FROM ListCoordinate JOIN (Fleets INNER JOIN Sectors
      ON (FleetType=2 AND FleetCGalaxy=SectorGalaxyId AND FleetCSector=SectorNumber) 
      INNER JOIN Units ON (UnitFleetId = FleetId)
      INNER JOIN UnitTypePortal USING (UnitTypeId)
      INNER JOIN Stars 
      ON (StarSectorId=SectorId AND StarX=FleetCX
      AND StarY=FleetCY AND StarId=_StarId)) ON (POW(FleetLocalX-x,2)+POW(FleetLocalY-y,2)<=POW(UnitTypePortalRadius, 2))) 
      ORDER BY RAND() LIMIT 1 
    );

   IF @CooId IS NULL THEN
       SELECT 'RouteNoDest' AS Result;
      LEAVE sproc;
    END IF;


   INSERT INTO Fleets(FleetId, FleetAccountId, FleetName, FleetCGalaxy, FleetCSector, FleetCX, FleetCY, 
                      FleetLocalX, FleetLocalY, FleetLocalDX, FleetLocalDY, FleetType, FleetState, FleetHidden, FleetHostId)
      SELECT 0, _AccountId, FleetName, SectorGalaxyId, SectorNumber, StarX, StarY, x, y, 0, 0, 2, 50, FleetHidden, NULL FROM Sectors
      INNER JOIN Stars ON (StarSectorId = SectorId) JOIN ListCoordinate JOIN Fleets ON(FleetId=_SrcId)
      WHERE StarId =_StarId AND id=@CooId LIMIT 1;

   SET @FleetId :=(SELECT LAST_INSERT_ID());

   call updateVisibleStar(_AccountId, _StarId);

   SET @DstUnitId := (SELECT CUT_UNITS(@UnitId, 1));
   UPDATE Units SET UnitFleetId=@FleetId WHERE UnitId=@DstUnitId;
 
   SET @EnergyCoeff := (SELECT PORTAL_ENERGY_COEFF(@FleetId));


   INSERT INTO UnitInstPortal(UnitId,UnitInstPortalDegree, UnitInstPortalDeployed, UnitInstPortalEnergy ) 
      SELECT UnitId, UnitTypePortalDegree, 1, UnitTypePortalEnergy * @EnergyCoeff 
      FROM UnitTypePortal INNER JOIN Units USING (UnitTypeId) WHERE UnitId=@DstUnitId;

 
  SELECT 'Ok' AS  Result;
 ELSE
    SELECT 'RouteNoUnits' AS Result; 

 END IF; 
END IF; 


SET @Cost1 := (SELECT COST_TUNNEL(_AccountId, S.FleetCGalaxy, S.FleetCSector, S.FleetCX, 
               S.FleetCY, D.FleetCGalaxy, D.FleetCSector, D.FleetCX, D.FleetCY,  PTS.UnitTypePortalSpeed, PTD.UnitTypePortalSpeed )
  FROM Fleets S JOIN Fleets D ON (S.FleetAccountId=D.FleetAccountId) INNER JOIN Units DT ON (DT.UnitId = @DstUnitId AND DT.UnitFleetId = D.FleetId) 
	INNER JOIN UnitTypePortal PTD ON(PTD.UnitTypeID = DT.UnitTypeId) 
	INNER JOIN Units ST ON (ST.UnitId = @ScrUnitId AND ST.UnitFleetId = S.FleetId) 
	INNER JOIN UnitTypePortal PTS ON(PTS.UnitTypeID = ST.UnitTypeId) 
  WHERE S.FleetId=_SrcId AND D.FleetId=@FleetId AND S.FleetAccountId=_AccountId );


SELECT CONCAT(SUBSTR(SA.StarName,1,60),' - ',SUBSTR(SB.StarName,1,60)) 
  FROM (Fleets A JOIN Stars SA ON(FleetCX=StarX AND FleetCY=StarY) JOIN Sectors SEA 
  ON(StarSectorId=SectorId AND FleetCSector=SectorNumber AND FleetCGalaxy=SectorGalaxyId)), 
  (Fleets B JOIN Stars SB ON(FleetCX=StarX AND FleetCY=StarY) JOIN Sectors SEB 
  ON(StarSectorId=SectorId AND FleetCSector=SectorNumber AND FleetCGalaxy=SectorGalaxyId))
  WHERE A.FleetId=_SrcId AND B.FleetId=@FleetId LIMIT 1
  INTO @Name;


INSERT INTO Routes 
  (RouteId, RouteOwnerAccountId, RouteSourcePortalId, RouteDestinationPortalId, 
  RouteDistance, RouteName)
  VALUES (0, _AccountId, _SrcId, @FleetId, @Cost1, @Name);


  SELECT 'Ok' AS Result;

END; 
END$$

