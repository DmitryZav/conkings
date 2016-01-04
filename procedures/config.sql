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
-- config procedure: keep all stored procedure variables
-----------------------------------------------------------------------------

-- --------------------------------------------------------------------------------
-- Routine DDL
-- --------------------------------------------------------------------------------
DELIMITER $$

CREATE DEFINER=`xgameuser`@`localhost` PROCEDURE `config`()
BEGIN
 
 -- IF @_ConfigDef <> 1 THEN
    SET @_ConfigDef:=1;
 
    SET @_AccNobody:=1;
    SET @_AccEvil:=2;
 
    SET @_PlanetInitialPopulation = 3000;
 
    SET @_CityId:=12;
    SET @_LabId=9;
    SET @_ResidenceId=13;
 
    SET @_FleetIdleState  :=0;
    SET @_FleetMoveState  :=1;
    SET @_FleetAttackState:=2;
    SET @_FleetBombState  :=3;
    SET @_FleetJumpState  :=5;
 
    SET @_FleetDigState     := 12;
    SET @_FleetReturnState  := 14;
    SET @_FleetDetonateState:= 15;
    SET @_FleetPortalState  := 50;
     
    SET @_ClassPortal :=8;
    SET @_ClassOrbiter:=11;
 
    SET @_ResourceEnergy:=6;
 
    SET @_DigBoxId := 3879;
 
    SET @_PortalProximitySqr := 4;
 
    SET @_FleetTypeRegular  := 1;
    SET @_FleetTypePortal   := 2;
    SET @_FleetTypeGarrison := 3;
    SET @_FleetTypeOrbiter  := 4;
 
    SET @_PortalThreshold := 0.5;
 
    SET @_HullEscape := 29;
 
--  END IF;
END
