-------------------------------------------------------------------------------
-- Copyright (c) 2010-2015 Dmitry Vazhenin <DmitryZav@users.noreply.github.com>
-- https://github.com/DmitryZav/
--
-- This file is part of Constellation Kings game project.
--
-- This file is subject to the terms and conditions defined in
-- file 'LICENSE', which is part of this source code package. 
--------------------------------------------------------------------------------
-- Truncated Gaussian distribution function
-- parameters:
-- mean - median value
-- stdev - deviation
-- a,b - interval of truncation
--------------------------------------------------------------------------------

DELIMITER $$

CREATE FUNCTION `GAUSS_TRUNC`(mean float, stdev float, a float, b float) RETURNS float
BEGIN

 SET @x := b+1;
 WHILE @x > b OR @x < a DO
  SET @x := ((sqrt(-2*log(rand()))*cos(2*pi()*rand()))*stdev)+mean;
 END WHILE;

RETURN @x;
END
