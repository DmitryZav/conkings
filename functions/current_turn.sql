-----------------------------------------------------------------------------
-- Copyright (c) 2010-2015 Dmitry Vazhenin <DmitryZav@users.noreply.github.com>
-- https://github.com/DmitryZav/
--
-- This file is part of Constellation Kings game project.
--
-- This file is subject to the terms and conditions defined in
-- file 'LICENSE', which is part of this source code package. 
-----------------------------------------------------------------------------
-- Function `CURRENT_TURN() returns current game turn number
-----------------------------------------------------------------------------

DELIMITER $$

CREATE DEFINER=`xgameuser`@`localhost` FUNCTION `CURRENT_TURN`() RETURNS int(10)
BEGIN

 RETURN (SELECT GameStateValue FROM GameState WHERE GameStateKey="Turn");

END
