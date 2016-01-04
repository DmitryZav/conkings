-----------------------------------------------------------------------------
-- Copyright (c) 2010-2015 Dmitry Vazhenin <DmitryZav@users.noreply.github.com>
-- https://github.com/DmitryZav/
--
-- This file is part of Constellation Kings game project.
--
-- This file is subject to the terms and conditions defined in
-- file 'LICENSE', which is part of this source code package. 
-----------------------------------------------------------------------------
-- repairUnits procedure, updates repair and regeneration effects on damaged units
-- part of the turn calculation loop
-----------------------------------------------------------------------------


DELIMITER $$

CREATE PROCEDURE `repairUnits`()
BEGIN

UPDATE Units U,
(SELECT FleetId, MAX(UnitEffectValue) AS EffectValue
FROM Fleets F
JOIN Units UU ON ( F.FleetId = UU.UnitFleetId )
JOIN UnitTypes UT
ON ( UU.UnitTypeId = UT.UnitTypeId )
JOIN UnitTypeEffects UE
ON  ( UE.UnitTypeId = UU.UnitTypeId)
JOIN EffectTypes ET ON ( ET.EffectTypeId = UE.UnitEffectId
AND EffectTypeName = 'unit_repair' ) GROUP BY FleetId) E,
(SELECT UnitId, UnitTypeHealth, FleetId FROM Units
INNER JOIN UnitTypes USING(UnitTypeId)
INNER JOIN Fleets ON (FleetId=UnitFleetId)
WHERE UnitHealth<UnitTypeHealth ) T
SET U.UnitHealth=
LEAST(UnitTypeHealth, FLOOR(T.UnitTypeHealth*E.EffectValue)+U.UnitHealth)
WHERE U.UnitId=T.UnitId AND U.UnitFleetId=E.FleetId;

UPDATE Units U,
(SELECT UT.UnitTypeId, UT.UnitTypeHealth, UnitEffectValue AS EffectValue
FROM 
UnitTypes UT
JOIN UnitTypeEffects UE
ON  ( UE.UnitTypeId = UT.UnitTypeId)
JOIN EffectTypes ET ON ( ET.EffectTypeId = UE.UnitEffectId
AND EffectTypeName = 'unit_selfrepair' )) E
SET U.UnitHealth=
LEAST(UnitTypeHealth, FLOOR(E.UnitTypeHealth*E.EffectValue)+U.UnitHealth)
WHERE U.UnitTypeId=E.UnitTypeId ;

UPDATE Buildings B,(

SELECT BuildingId,BuildingTopHealth, BuildingTypeHealth,
IF(BuildingTopHealth < BuildingTypeHealth, BuildingTopHealth+0.1*BuildingTypeHealth, BuildingTypeHealth) as HP
FROM Buildings JOIN POwners ON(POwnersPlanetId=BuildingPlanetId) JOIN 
BuildingTypes USING (BuildingTypeId) 
LEFT JOIN (
  SELECT ResourceAccountingId FROM ResourceAccounting JOIN ResourceTypes 
  ON(ResourceAccountingTypeId=ResourceTypeId AND ResourceTypeStorable=1) 
   WHERE ResourceAccountingValue < 0 GROUP BY ResourceAccountingId
) R ON (POwnersAccountId=ResourceAccountingId)
WHERE BuildingTopHealth < BuildingTypeHealth AND ResourceAccountingId IS NULL

) H SET B.BuildingTopHealth=IF(H.HP>0,H.HP,0) WHERE B.BuildingId=H.BuildingId;

END
