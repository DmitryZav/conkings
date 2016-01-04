-----------------------------------------------------------------------------
-- Copyright (c) 2010-2015 Dmitry Vazhenin <DmitryZav@users.noreply.github.com>
-- https://github.com/DmitryZav/
--
-- This file is part of Constellation Kings game project.
--
-- This file is subject to the terms and conditions defined in
-- file 'LICENSE', which is part of this source code package. 
-----------------------------------------------------------------------------
-- Dijkstra algorithm to find shortest path in the routes network
-- parameters:
-- AccountId - routes owner or shared user
-- _SrcId - from which star to begin
-- _DestId - to which star to finish
-- _NavFlag - flags to navigate to 
-----------------------------------------------------------------------------
DELIMITER $$

CREATE DEFINER=`xgameuser`@`localhost` PROCEDURE `DIJKSTRA`(_AccountId INT unsigned, _SrcId INT unsigned, _DestId INT unsigned, _NavFlag INT)
BEGIN

-- call debug(CONCAT('dijkstra (',CURRENT_TURN(),'): ',_AccountId,', from ', _SrcId,' to ', _DestId, ' Nav=', _NavFlag));

CREATE TEMPORARY TABLE IF NOT EXISTS StarList (
        `StarId` Integer unsigned NOT NULL,    
        `Estimate` float NOT NULL,  
        `Pred` Integer unsigned DEFAULT NULL,
        `Distance` float NOT NULL,   
        `Tunnel` Integer unsigned NOT NULL,
        `Done` Tinyint NOT NULL,
        PRIMARY KEY (`StarId`) USING BTREE,
        KEY `StarIndex` (`StarId`) USING BTREE,
        KEY `TunnelIndex` (`Tunnel`) USING BTREE
) ENGINE=MEMORY;

CREATE TEMPORARY TABLE IF NOT EXISTS TabRoutes (
        `TabRouteId` Integer unsigned NOT NULL,    
        `SrcId` Integer unsigned NOT NULL,
        `DestId` Integer unsigned NOT NULL,
        `SrcPortalId` Integer unsigned NOT NULL,
        `DestPortalId` Integer unsigned NOT NULL,
        `Dist` float NOT NULL,  
        `OwnerId` Integer unsigned NOT NULL,
        PRIMARY KEY (`TabRouteId`) USING BTREE,
        KEY `StarIndex1` (`SrcId`) USING BTREE,
        KEY `StarIndex2` (`DestId`) USING BTREE,
        KEY `PortalIndex1` (`SrcPortalId`) USING BTREE,
        KEY `PortalIndex2` (`DestPortalId`) USING BTREE,
        KEY `OwnerIndex` (`OwnerId`) USING BTREE
) ENGINE=MEMORY;

CREATE TEMPORARY TABLE IF NOT EXISTS StarsPath (
        `PathId` Integer unsigned NOT NULL AUTO_INCREMENT,
        `StarId` Integer unsigned NOT NULL,    
        `FleetId` Integer unsigned NOT NULL,    
        `Dist` float NOT NULL,
        `TunId` Integer DEFAULT NULL,
	PRIMARY KEY (`PathId`) USING BTREE,
  KEY `StarIndex` (`StarId`) USING BTREE,
  KEY `TunnelIndex` (`TunId`) USING BTREE
) AUTO_INCREMENT=1 ENGINE=MEMORY;

DELETE FROM TabRoutes;
DELETE FROM StarList;
DELETE FROM StarsPath;

INSERT INTO TabRoutes (TabRouteId, Dist, SrcId, DestId, SrcPortalId, DestPortalId,OwnerId)
SELECT RouteId, 1, SRC.StarId AS SrcStarId, DST.StarId AS DestStarId, 
S.FleetId, D.FleetId, RouteOwnerAccountId as AccountId 
FROM
  Routes JOIN (Fleets S
  JOIN Sectors SS ON ( SS.SectorNumber = S.FleetCSector
  AND SS.SectorGalaxyId = S.FleetCGalaxy ) 
  JOIN Stars SRC ON ( SRC.StarX = S.FleetCX
  AND SRC.StarY = S.FleetCY 
  AND SRC.StarSectorId = SS.SectorId AND SS.SectorGalaxyId = S.FleetCGalaxy )) ON ( S.FleetId = RouteSourcePortalId )
  JOIN ( Fleets D
  JOIN Sectors DS ON ( DS.SectorNumber = D.FleetCSector
  AND DS.SectorGalaxyId = D.FleetCGalaxy )
  JOIN Stars DST ON ( DST.StarX = D.FleetCX
  AND DST.StarY = D.FleetCY AND DST.StarSectorId = DS.SectorId 
  AND DS.SectorGalaxyId = D.FleetCGalaxy ))ON ( D.FleetId = RouteDestinationPortalId )
  WHERE RouteOwnerAccountId=_AccountId
UNION
SELECT RouteId, 1.1, SRC.StarId AS SrcStarId, DST.StarId AS DestStarId, 
S.FleetId, D.FleetId, RouteOwnerAccountId as AccountId 
FROM Routes 
 JOIN ( Fleets S 
  JOIN Sectors SS ON ( SS.SectorNumber = S.FleetCSector
 AND SS.SectorGalaxyId = S.FleetCGalaxy ) 
 JOIN Stars SRC ON ( SRC.StarX = S.FleetCX
 AND SRC.StarY = S.FleetCY 
 AND SRC.StarSectorId = SS.SectorId 
 AND SS.SectorGalaxyId = S.FleetCGalaxy ))  ON ( S.FleetId = RouteSourcePortalId )
 JOIN ( Fleets D 
 JOIN Sectors DS ON ( DS.SectorNumber = D.FleetCSector
 AND DS.SectorGalaxyId = D.FleetCGalaxy ) 
 JOIN Stars DST ON ( DST.StarX = D.FleetCX
 AND DST.StarY = D.FleetCY AND DST.StarSectorId = DS.SectorId 
 AND DS.SectorGalaxyId = D.FleetCGalaxy ))ON ( D.FleetId = RouteDestinationPortalId )
 JOIN RoutePermissions ON (RoutePermissionActive =1 AND RoutePermissionRouteId = RouteId )
 JOIN PermissionTypes ON (PermissionName='tunnel.use' AND PermissionTypeId=RoutePermissionTypeId)
 JOIN Accounts OWN ON (RouteOwnerAccountId= OWN.AccountId) JOIN Accounts ACT ON (ACT.AccountId=_AccountId AND 
 ACT.AccountId <> OWN.AccountId AND IFNULL(OWN.AccountCountryId, -1)<>IFNULL(ACT.AccountCountryId, -2) )
 WHERE RoutePermissionAccountId=_AccountId AND _NavFlag = 0
UNION
SELECT RouteId, 1.1, SRC.StarId AS SrcStarId, DST.StarId AS DestStarId, 
S.FleetId, D.FleetId, RouteOwnerAccountId as AccountId 
FROM Routes
 JOIN ( Fleets S
  JOIN Sectors SS ON ( SS.SectorNumber = S.FleetCSector
 AND SS.SectorGalaxyId = S.FleetCGalaxy )
 JOIN Stars SRC ON ( SRC.StarX = S.FleetCX
 AND SRC.StarY = S.FleetCY
 AND SRC.StarSectorId = SS.SectorId
 AND SS.SectorGalaxyId = S.FleetCGalaxy )) ON ( S.FleetId = RouteSourcePortalId )
 JOIN ( Fleets D
 JOIN Sectors DS ON ( DS.SectorNumber = D.FleetCSector
 AND DS.SectorGalaxyId = D.FleetCGalaxy )
  JOIN Stars DST ON ( DST.StarX = D.FleetCX
 AND DST.StarY = D.FleetCY
 AND DST.StarSectorId = DS.SectorId
 AND DS.SectorGalaxyId = D.FleetCGalaxy )) ON ( D.FleetId = RouteDestinationPortalId )
JOIN Accounts OWN ON (RouteOwnerAccountId= OWN.AccountId) JOIN Accounts ACT ON (ACT.AccountId=_AccountId AND 
ACT.AccountId <> OWN.AccountId AND IFNULL(OWN.AccountCountryId, -1)=IFNULL(ACT.AccountCountryId, -2) )
WHERE _NavFlag = 0;


INSERT INTO StarList (StarId, Estimate, Pred, Distance, Tunnel, Done)
SELECT DISTINCT StarId, 2147483647, NULL, 0, 0, 0 from Stars JOIN TabRoutes 
WHERE StarId=TabRoutes.DestId OR StarId=TabRoutes.SrcId;

UPDATE StarList SET Estimate = 0 WHERE StarId = _SrcId;

SET @FromStar = NULL;
SET @CurrentEstimate = NULL;
SET @Cnt=2000;


lab:LOOP
  SET @Cnt = @Cnt - 1;

  SET @FromStar = NULL;
  SELECT StarId, Estimate FROM StarList WHERE Done = 0 AND Estimate < 2147483647
  ORDER BY Estimate LIMIT 1 INTO @FromStar, @CurrentEstimate;

  IF @FromStar IS NULL THEN LEAVE lab; END IF;

  UPDATE StarList SET Done = 1 WHERE StarId = @FromStar;

  UPDATE StarList, TabRoutes 
  SET Estimate = @CurrentEstimate + Dist, Pred = @FromStar, Tunnel = TabRouteId 
  WHERE  
  ((SrcId = StarId AND DestId = @FromStar) OR 
  (SrcId = @FromStar AND DestId = StarId )) AND  (@CurrentEstimate + Dist) < Estimate;
 
  IF @Cnt < 1 THEN LEAVE lab; END IF;
END LOOP;


IF EXISTS (SELECT * FROM StarList WHERE StarId = _DestId AND Estimate < 2147483647) THEN

SET @CurrentId = _DestId;
SET @NextId = 0;
SET @CurrentFleetId = 0;
SET @PathDist = 0;
SET @CurrentPath = 0;
SET @TunId = 0;

  lab1:LOOP

    SELECT Pred, IF(SrcId = Pred, SrcPortalId, DestPortalId) as FleetId, Estimate, Tunnel FROM TabRoutes 
    JOIN StarList ON 
    ((SrcId = Pred AND DestId = @CurrentId) OR 
    (SrcId = @CurrentId AND DestId = Pred ))
    WHERE StarId=@CurrentId AND Tunnel=TabRouteId
    INTO @NextId, @CurrentFleetId, @PathDist, @TunId;

    IF @NextId = 0 OR @NextId IS NULL OR @PathDist > 2147483646 THEN 
      LEAVE lab1; 
    END IF;

    INSERT INTO StarsPath (`PathId`,`StarId`,`FleetId`,`Dist`,`TunId`)
        VALUES (0, @CurrentId, @CurrentFleetId, @PathDist, @TunId);

    call debug(CONCAT('path fleet:', @CurrentId, ', route: ', @TunId));

    SET @CurrentId = @NextId;
    SET @NextId = NULL;

  END LOOP;


END IF;



END
